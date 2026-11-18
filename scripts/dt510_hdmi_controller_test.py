#!/usr/bin/env python3
"""Native tests of the actual bounded diagnostic hooks, not hardware proof."""
import re


def check_controller_diagnostics(source, work, run):
    def actual(name):
        return re.search(r"static (?:int|bool|irqreturn_t) " + name + r"\(.*?\n\}", source, re.S).group()

    diag = re.search(r"struct imx_i2c_dt510_diag \{.*?\n\};", source, re.S).group()
    harness = r'''
#include <assert.h>
#include <stdbool.h>
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
typedef unsigned long long u64;
typedef int irqreturn_t;
#define __iomem
#define IRQ_NONE 0
#define IRQ_HANDLED 1
#define I2SR_IIF 2
#define I2SR_IAL 16
#define I2CR_MSTA 32
#define IMX_I2C_I2SR 0
#define IMX_I2C_I2CR 1
#define I2C_M_RD 1
#define I2C_M_TEN 16
#define I2C_M_RECV_LEN 1024
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
#define READ_ONCE(v) (v)
#define unlikely(v) (v)
#define min_t(t,a,b) ((t)(a)<(t)(b)?(t)(a):(t)(b))
#define dev_dbg(...) ((void)0)
#define wake_up(q) ((void)(q))
static unsigned int lock_depth, logs, raw_calls, wait_calls, raw_steps;
static int raw_result, miss_wait;
static bool raw_running;
static u64 tick;
static u64 ktime_get_ns(void) { tick+=1000; return tick; }
#define spin_lock_irqsave(l,f) do { (void)(l); (f)=0; assert(!lock_depth); lock_depth++; } while(0)
#define spin_unlock_irqrestore(l,f) do { (void)(l); (void)(f); assert(lock_depth==1); lock_depth--; } while(0)
static void info(void *dev, const char *fmt, ...) __attribute__((format(printf,2,3)));
static void info(void *dev, const char *fmt, ...)
{ (void)dev; (void)fmt; assert(!raw_running && !lock_depth); logs++; }
#define dev_info info
'''
    harness += diag + r'''
struct i2c_adapter { int nr, dev; };
struct i2c_msg { unsigned int addr,flags,len; unsigned char *buf; };
struct imx_i2c_struct {
    struct i2c_adapter adapter;
    struct imx_i2c_dt510_diag dt510_diag;
    unsigned long i2csr;
    unsigned int cur_clk, ifdr;
    int slave_lock, queue;
    void *base, *slave;
    struct { unsigned int regshift; } *hwdata;
};
static struct imx_i2c_struct *target;
static struct imx_i2c_struct *i2c_get_adapdata(struct i2c_adapter *a)
{ assert(a==&target->adapter); return target; }
static unsigned int imx_i2c_read_reg(struct imx_i2c_struct *d, unsigned int reg)
{ assert(d==target && lock_depth==1); return reg==IMX_I2C_I2SR?0x82:I2CR_MSTA; }
static void i2c_imx_clear_irq(struct imx_i2c_struct *d, unsigned int mask)
{ (void)d; (void)mask; }
static int i2c_imx_slave_handle(struct imx_i2c_struct *d,unsigned int s,unsigned int c)
{ (void)d; (void)s; (void)c; assert(0); return 0; }
static void i2c_imx_slave_finish_op(struct imx_i2c_struct *d) { (void)d; assert(0); }
'''
    harness += actual('i2c_imx_master_isr') + '\n' + actual('i2c_imx_isr')
    harness += r'''
static void complete_wait(struct imx_i2c_struct *d)
{
    if ((int)wait_calls++==miss_wait) { tick+=100000000; d->i2csr=0; }
    else assert(i2c_imx_isr(205,d)==IRQ_HANDLED);
}
#define HZ 1000
#define wait_event_timeout(q,c,t) do { (void)(q); (void)(t); complete_wait(i2c_imx); (void)(c); } while(0)
#define readb_poll_timeout_atomic(a,v,c,d,t) do { (void)(a); (void)(d); (void)(t); (v)=I2SR_IIF; (void)(c); } while(0)
'''
    harness += actual('i2c_imx_trx_complete')
    harness += r'''
static int i2c_imx_xfer_raw(struct i2c_adapter *a,struct i2c_msg *m,int n)
{
    (void)m; (void)n; assert(a==&target->adapter); raw_calls++; raw_running=true;
    for (unsigned int k=0;k<raw_steps;k++) {
        int ret=i2c_imx_trx_complete(target,false);
        if (ret) { raw_running=false; return ret; }
    }
    raw_running=false; return raw_result;
}
'''
    harness += actual('i2c_imx_dt510_clock_msg') + '\n' + actual('i2c_imx_xfer')
    harness += r'''
int main(void)
{
    struct imx_i2c_struct d={.adapter={.nr=2},.cur_clk=24000000}; target=&d;
    unsigned char bytes[]={1,24};
    struct i2c_msg m={.addr=0x39,.len=2,.buf=bytes};
    assert(i2c_imx_dt510_clock_msg(&d.adapter,&m,1));
    assert(!i2c_imx_dt510_clock_msg(&d.adapter,NULL,0));
    for (unsigned int k=0;k<8;k++) {
        struct i2c_msg bad=m; d.adapter.nr=2;
        if(k==0)d.adapter.nr=1;
        if(k==1)bad.addr=0x3b;
        if(k==2)bad.flags=I2C_M_RD;
        if(k==3)bad.flags=I2C_M_TEN;
        if(k==4)bad.flags=I2C_M_RECV_LEN;
        if(k==5)bad.len=1;
        if(k==6)bad.buf=NULL;
        if(k==7)bytes[1]=8;
        assert(!i2c_imx_dt510_clock_msg(&d.adapter,&bad,1));
        logs=raw_calls=wait_calls=0; raw_steps=0; raw_result=-EIO; miss_wait=-1;
        assert(i2c_imx_xfer(&d.adapter,&bad,1)==-EIO && raw_calls==1 && !logs);
        bytes[1]=24;
    }
    d.adapter.nr=2;
    const int results[]={1,-ENXIO,-EAGAIN,-ETIMEDOUT,-EIO,-EBUSY};
    for(unsigned int k=0;k<ARRAY_SIZE(results);k++) {
        logs=raw_calls=wait_calls=0; raw_steps=3; raw_result=results[k]; miss_wait=-1;
        assert(i2c_imx_xfer(&d.adapter,&m,1)==results[k] && raw_calls==1);
        assert(logs==8 && !d.dt510_diag.active && !lock_depth);
        assert(d.dt510_diag.waits==3 && d.dt510_diag.irqs==3);
        for(unsigned int n=0;n<3;n++) {
            assert(d.dt510_diag.wait[n].sr==0x82 && d.dt510_diag.wait[n].irqs==n+1);
            assert(d.dt510_diag.irq[n].sr==0x82 && d.dt510_diag.irq[n].cr==I2CR_MSTA);
        }
    }
    for(int k=0;k<3;k++) {
        logs=raw_calls=wait_calls=0; raw_steps=3; raw_result=1; miss_wait=k;
        assert(i2c_imx_xfer(&d.adapter,&m,1)==-ETIMEDOUT);
        assert(d.dt510_diag.waits==(unsigned int)k+1 && d.dt510_diag.irqs==(unsigned int)k);
        assert(d.dt510_diag.wait[k].sr==0 && d.dt510_diag.wait[k].ns>=100000000);
    }
    logs=raw_calls=wait_calls=0; raw_steps=6; raw_result=1; miss_wait=-1;
    assert(i2c_imx_xfer(&d.adapter,&m,1)==1 && logs==9);
    assert(d.dt510_diag.waits==6 && d.dt510_diag.irqs==6);
    assert(!d.dt510_diag.active && !lock_depth);
    return 0;
}
'''
    path = work / 'controller-diagnostics.c'
    path.write_text(harness)
    binary = work / 'controller-diagnostics'
    # Kernel IRQ callback prototypes routinely leave the irq argument unused.
    run(['cc','-Wall','-Wextra','-Werror','-Wno-unused-parameter','-std=c11',
         '-fsanitize=address,undefined',str(path),'-o',str(binary)])
    run([str(binary)])
    print('PASS: actual controller matcher/wrapper/byte-wait/ISR: scope exclusions, unchanged returns, each missing IRQ, capped samples, lock cleanup and post-transfer-only output; ASan/UBSan. Not kernel/boot proof.')

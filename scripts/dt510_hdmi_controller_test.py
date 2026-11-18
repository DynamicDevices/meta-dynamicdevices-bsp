#!/usr/bin/env python3
"""Native tests of the actual bounded diagnostic hooks, not hardware proof."""
import re


def check_controller_diagnostics(source, work, run):
    def actual(name):
        return re.search(r"static (?:int|bool|void|irqreturn_t) " + name + r"\([^;{]*\)\n\{.*?\n\}", source, re.S).group()

    diag = re.search(r"struct imx_i2c_dt510_diag \{.*?\n\};", source, re.S).group()
    harness = r'''
#include <assert.h>
#include <stdbool.h>
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
typedef unsigned long long u64;
typedef unsigned int u32;
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
#define WRITE_ONCE(v,x) ((v)=(x))
#define unlikely(v) (v)
#define min_t(t,a,b) ((t)(a)<(t)(b)?(t)(a):(t)(b))
#define dev_dbg(...) ((void)0)
#define wake_up(q) ((void)(q))
static unsigned int lock_depth, logs, raw_calls, wait_calls, raw_steps, sleeps;
static int raw_result, miss_wait;
static bool raw_running;
static u64 tick;
static u64 ktime_get_ns(void) { tick+=1000; return tick; }
static void usleep_range(unsigned int lo, unsigned int hi)
{ assert(!lock_depth && raw_running && lo==50000 && hi==51000); sleeps++; tick+=(u64)lo*1000; }
static unsigned int dt510_lt9611_stop_delay_us=50000;
struct kernel_param { void *arg; };
static int kstrtouint(const char *s, unsigned int base, unsigned int *out)
{ char *end; unsigned long n; errno=0; n=strtoul(s,&end,base);
  if(errno || *end || !*s || *s=='-' || n>0xffffffffUL) return -EINVAL;
  *out=n; return 0; }
struct device_node { int dummy; };
struct device { struct device *parent; struct device_node *of_node; };
static struct device_node lt_node;
static bool machine_ok=true, child_ok=true, available=true, compatible=true;
static int reg_error;
static u32 reg_value=0x39;
static unsigned int gets, node_puts;
static bool of_machine_is_compatible(const char *s)
{ assert(!strcmp(s,"fsl,imx8mm-jaguar-dt510")); return machine_ok; }
static struct device_node *of_get_child_by_name(struct device_node *n,const char *s)
{ /* of_node_name_eq compares the basename, excluding @unit-address. */
  const char *full="lt9611@39", *at=strchr(full,'@');
  assert(n); if(!child_ok || strlen(s)!=(size_t)(at-full) || strncmp(full,s,at-full)) return NULL;
  gets++; return &lt_node; }
static bool of_device_is_available(struct device_node *n)
{ assert(n==&lt_node); return available; }
static bool of_device_is_compatible(struct device_node *n,const char *s)
{ assert(n==&lt_node && !strcmp(s,"lontium,lt9611")); return compatible; }
static int of_property_read_u32(struct device_node *n,const char *s,u32 *v)
{ assert(n==&lt_node && !strcmp(s,"reg")); *v=reg_value; return reg_error; }
static void of_node_put(struct device_node *n) { assert(n==&lt_node); node_puts++; }
#define spin_lock_irqsave(l,f) do { (void)(l); (f)=0; assert(!lock_depth); lock_depth++; } while(0)
#define spin_unlock_irqrestore(l,f) do { (void)(l); (void)(f); assert(lock_depth==1); lock_depth--; } while(0)
static void info(void *dev, const char *fmt, ...) __attribute__((format(printf,2,3)));
static void info(void *dev, const char *fmt, ...)
{ (void)dev; (void)fmt; assert(!raw_running && !lock_depth); logs++; }
#define dev_info info
'''
    harness += diag + r'''
struct i2c_adapter { int nr; struct device dev; };
struct i2c_msg { unsigned int addr,flags,len; unsigned char *buf; };
struct imx_i2c_struct {
    struct i2c_adapter adapter;
    struct imx_i2c_dt510_diag dt510_diag;
    bool dt510_page_valid;
    unsigned int dt510_page, dt510_stop_delay_this_xfer;
    unsigned long i2csr;
    unsigned int cur_clk, ifdr;
    int slave_lock, queue;
    void *base, *slave, *clk;
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
    harness += actual('i2c_imx_dt510_clock_msg') + '\n'
    harness += actual('i2c_imx_dt510_settle') + '\n'
    harness += actual('i2c_imx_dt510_set_stop_delay') + '\n'
    harness += actual('i2c_imx_dt510_board') + '\n'
    harness += actual('i2c_imx_dt510_track_page') + '\n'
    harness += r'''
static int i2c_imx_xfer_raw(struct i2c_adapter *a,struct i2c_msg *m,int n)
{
    (void)m; (void)n; assert(a==&target->adapter); raw_calls++; raw_running=true;
    for (unsigned int k=0;k<raw_steps;k++) {
        int ret=i2c_imx_trx_complete(target,false);
        if (ret) { raw_running=false; return ret; }
    }
    if(raw_result==n && n==1) i2c_imx_dt510_settle(target,m,false);
    raw_running=false; return raw_result;
}
'''
    harness += actual('i2c_imx_xfer')
    harness += r'''
static int clock_error, atomic_result;
static unsigned int atomic_calls, disables;
static int clk_enable(void *clk) { (void)clk; return clock_error; }
static void clk_disable(void *clk) { (void)clk; disables++; }
static int i2c_imx_xfer_common(struct i2c_adapter *a,struct i2c_msg *m,int n,bool atomic)
{ assert(a==&target->adapter && atomic && n==1); atomic_calls++;
  i2c_imx_dt510_settle(target,m,atomic); return atomic_result; }
'''
    harness += actual('i2c_imx_xfer_atomic')
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
        assert(logs==9 && !d.dt510_diag.active && !lock_depth);
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
    assert(i2c_imx_xfer(&d.adapter,&m,1)==1 && logs==10);
    assert(d.dt510_diag.waits==6 && d.dt510_diag.irqs==6);
    assert(!d.dt510_diag.active && !lock_depth);
    struct device parent={.of_node=&lt_node}; d.adapter.dev.parent=&parent;
    assert(!of_get_child_by_name(&lt_node,"lt9611@39"));
    assert(i2c_imx_dt510_board(&d.adapter) && gets==node_puts);
    for(unsigned int k=0;k<7;k++) {
        if(k==0)d.adapter.nr=1;
        if(k==1)d.adapter.dev.parent=NULL;
        if(k==2)machine_ok=false;
        if(k==3)child_ok=false;
        if(k==4)available=false;
        if(k==5)compatible=false;
        if(k==6)reg_error=-EINVAL;
        assert(!i2c_imx_dt510_board(&d.adapter) && gets==node_puts);
        d.adapter.nr=2; d.adapter.dev.parent=&parent;
        machine_ok=child_ok=available=compatible=true; reg_error=0;
    }
    reg_value=0x38; assert(!i2c_imx_dt510_board(&d.adapter)); reg_value=0x39;
    assert(gets==node_puts);
    parent.of_node=NULL; assert(!i2c_imx_dt510_board(&d.adapter)); parent.of_node=&lt_node;
    struct kernel_param kp={.arg=&dt510_lt9611_stop_delay_us};
    const char *invalid[]={"1","50001","-1","bad","4294967296"};
    for(unsigned int k=0;k<ARRAY_SIZE(invalid);k++) {
        assert(i2c_imx_dt510_set_stop_delay(invalid[k],&kp)<0);
        assert(dt510_lt9611_stop_delay_us==50000);
    }
    raw_steps=3; raw_result=1; miss_wait=-1;
    unsigned char page[]={0xff,0x81};
    struct i2c_msg p={.addr=0x39,.len=2,.buf=page};
    for(unsigned int delay=0;delay<=50000;delay+=50000) {
        assert(!i2c_imx_dt510_set_stop_delay(delay?"50000":"0",&kp));
        assert(i2c_imx_xfer(&d.adapter,&p,1)==1 && d.dt510_page_valid);
        unsigned int before=sleeps;
        assert(i2c_imx_xfer(&d.adapter,&m,1)==1);
        assert(d.dt510_diag.settle_eligible && d.dt510_diag.settle_requested_us==delay);
        assert(sleeps==before+(delay!=0));
        assert(delay?d.dt510_diag.settle_ns>=50000000:!d.dt510_diag.settle_ns);
        assert(!d.dt510_page_valid && !d.dt510_stop_delay_this_xfer);
        before=sleeps;
        assert(i2c_imx_xfer(&d.adapter,&m,1)==1 && sleeps==before);
        if(delay)break;
    }
    for(unsigned int k=0;k<8;k++) {
        assert(i2c_imx_xfer(&d.adapter,&p,1)==1);
        struct i2c_msg bad=p;
        if(k==0)bad.flags=I2C_M_RD;
        if(k==1)bad.flags=I2C_M_TEN;
        if(k==2)bad.flags=I2C_M_RECV_LEN;
        if(k==3)bad.len=1;
        if(k==4)bad.buf=NULL;
        if(k==5)bad.buf=bytes;
        i2c_imx_dt510_track_page(&d,&bad,1,k==6?-EIO:k==7?0:1);
        assert(!d.dt510_page_valid);
    }
    assert(i2c_imx_xfer(&d.adapter,&p,1)==1);
    struct i2c_msg other=p; other.addr=0x38;
    i2c_imx_dt510_track_page(&d,&other,1,1); assert(d.dt510_page_valid);
    struct i2c_msg pair[]={other,p};
    i2c_imx_dt510_track_page(&d,pair,2,2); assert(!d.dt510_page_valid);
    page[1]=0x80; assert(i2c_imx_xfer(&d.adapter,&p,1)==1);
    unsigned int before=sleeps;
    assert(i2c_imx_xfer(&d.adapter,&m,1)==1 && sleeps==before);
    page[1]=0x81;
    for(unsigned int k=1;k<ARRAY_SIZE(results);k++) {
        raw_result=1; assert(i2c_imx_xfer(&d.adapter,&p,1)==1);
        raw_result=results[k]; before=sleeps;
        assert(i2c_imx_xfer(&d.adapter,&m,1)==results[k] && sleeps==before);
        assert(!d.dt510_page_valid && !d.dt510_stop_delay_this_xfer);
    }
    for(int k=0;k<3;k++) {
        raw_result=1; miss_wait=-1; assert(i2c_imx_xfer(&d.adapter,&p,1)==1);
        miss_wait=k; wait_calls=0; before=sleeps;
        assert(i2c_imx_xfer(&d.adapter,&m,1)==-ETIMEDOUT && sleeps==before);
    }
    d.dt510_stop_delay_this_xfer=50000; raw_running=true; before=sleeps;
    i2c_imx_dt510_settle(&d,&m,true); assert(sleeps==before);
    i2c_imx_dt510_settle(&d,&other,false); assert(sleeps==before);
    raw_running=false;
    for(unsigned int k=0;k<2;k++) {
        d.dt510_page_valid=true; d.dt510_page=0x81;
        clock_error=k?-EIO:0; atomic_result=-EAGAIN; before=sleeps;
        assert(i2c_imx_xfer_atomic(&d.adapter,&m,1)==(k?-EIO:-EAGAIN));
        assert(!d.dt510_page_valid && sleeps==before);
    }
    assert(atomic_calls==1 && disables==1);
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
    print('PASS: actual controller matcher/wrapper/byte-wait/ISR and post-ACK helper: 0/50000us control, invalid values, board/node references, page tracking, error/atomic/unrelated exclusions, delay measurement, capped capture and post-transfer-only output; ASan/UBSan. PIO placement tested separately; not kernel/boot proof.')

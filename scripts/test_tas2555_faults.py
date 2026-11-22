#!/usr/bin/env python3
"""Compile and exercise real patched driver functions with a fake register bus.

Usage: python3 scripts/test_tas2555_faults.py PATH_TO_PATCHED_TI_DRIVER
Uses the driver's actual functions/constants, not a Python copy of its decoder.
"""
import argparse
from pathlib import Path
import re
import subprocess
import tempfile


def function(source, name):
    match = re.search(r"^(?:static )?int " + name + r"\(", source, re.M)
    if not match:
        raise ValueError(f"missing function {name}")
    end = source.index("\n}", match.start()) + 2
    return source[match.start():end]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("driver", type=Path)
    args = parser.parse_args()
    header = (args.driver / "tas2555.h").read_text()
    macros = []
    for name in ["TAS2555_FLAGS_1", "TAS2555_FLAGS_2", "TAS2555_CLK_ERR_CTRL1"]:
        match = re.search(r"^#define\s+" + name + r"\s+TAS2555_REG\(0,\s*0,\s*(\d+)\)", header, re.M)
        if not match:
            raise ValueError(f"unexpected register definition {name}")
        macros.append(f"#define {name} {match[1]}")
    macros += re.findall(r"^#define\s+TAS2555_ERROR_\w+\s+0x[0-9a-fA-F]+", header, re.M)
    functions = function((args.driver / "tas2555-core.c").read_text(), "tas2555_get_errcode")
    functions += "\n" + function((args.driver / "tas2555-codec.c").read_text(), "tas2555_errcode_get")
    harness = r'''
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#define KCONTROL_CODEC 1
#define dev_dbg(...) ((void)0)
struct tas2555_priv {
    int (*read)(struct tas2555_priv *, unsigned int, unsigned int *);
    int (*write)(struct tas2555_priv *, unsigned int, unsigned int);
    unsigned int mnErrorCode;
    void *dev;
};
struct snd_soc_component { struct tas2555_priv *priv; };
struct snd_kcontrol { struct snd_soc_component *component; };
struct snd_ctl_elem_value { struct { struct { long value[1]; } integer; } value; };
static struct snd_soc_component *snd_soc_kcontrol_component(struct snd_kcontrol *k) { return k->component; }
static struct tas2555_priv *snd_soc_component_get_drvdata(struct snd_soc_component *c) { return c->priv; }
static unsigned int flags104, flags108, reads, writes, shutdowns;
static int fail_read;
static int fake_read(struct tas2555_priv *p, unsigned int reg, unsigned int *value) {
    (void)p;
    ++reads;
    if ((int)reads == fail_read) return -EIO;
    assert(reg == (reads == 1 ? 108U : 104U));
    *value = reg == 104 ? flags104 : flags108;
    if (reg == 104) flags104 = 0; /* Real sticky faults clear on read. */
    return 0;
}
static int fake_write(struct tas2555_priv *p, unsigned int reg, unsigned int value) {
    (void)p;
    assert(reg == 44 && value == 0);
    ++writes;
    return 0;
}
static int tas2555_enable(struct tas2555_priv *p, bool enable) {
    (void)p;
    assert(!enable);
    ++shutdowns;
    return 0;
}
static void reset(unsigned int a, unsigned int b) {
    flags104=a; flags108=b; reads=writes=shutdowns=0; fail_read=0;
}
'''
    cases = r'''
int main(void) {
    struct tas2555_priv p = {.read=fake_read, .write=fake_write};
    struct snd_soc_component c = {.priv=&p};
    struct snd_kcontrol k = {.component=&c};
    struct snd_ctl_elem_value v;
    unsigned int a, b, result, expected;
    for (a=0; a<256; ++a) for (b=0; b<256; ++b) {
        reset(a,b); p.mnErrorCode=0; result=0;
        expected = (a&4 ? TAS2555_ERROR_CLKPRESENT : 0)
                 | (a&8 ? TAS2555_ERROR_BROWNOUT : 0)
                 | (a&16 ? TAS2555_ERROR_OVERTMP : 0)
                 | (a&64 ? TAS2555_ERROR_UNDERVOLTAGET : 0)
                 | (a&128 ? TAS2555_ERROR_OVERCURRENT : 0);
        assert(tas2555_get_errcode(&p,&result)==0);
        assert(result==expected && reads==2);
        assert(writes==(!!(a&4)) && shutdowns==(!!(a&0xdc)));
    }
    reset(8,0); p.mnErrorCode=TAS2555_ERROR_I2CIO;
    assert(tas2555_get_errcode(&p,&result)==0);
    assert(result==(TAS2555_ERROR_I2CIO|TAS2555_ERROR_BROWNOUT));
    assert(p.mnErrorCode==0);
    for (int failure=1; failure<=2; ++failure) {
        reset(8,0); fail_read=failure; result=0xdeadbeef;
        p.mnErrorCode=TAS2555_ERROR_I2CIO;
        assert(tas2555_get_errcode(&p,&result)==-EIO);
        assert(result==0xdeadbeef && p.mnErrorCode==TAS2555_ERROR_I2CIO);
        assert(reads==(unsigned int)failure && writes==0 && shutdowns==0);
        assert(flags104==8); /* Failed status reads must not consume faults. */
        fail_read=0; reads=0;
        assert(tas2555_get_errcode(&p,&result)==0);
        assert(result==(TAS2555_ERROR_I2CIO|TAS2555_ERROR_BROWNOUT));
        assert(shutdowns==1 && flags104==0 && p.mnErrorCode==0);
        reset(8,0); fail_read=failure; v.value.integer.value[0]=12345;
        assert(tas2555_errcode_get(&k,&v)==-EIO);
        assert(v.value.integer.value[0]==12345);
    }
    reset(8,0); p.mnErrorCode=0;
    assert(tas2555_errcode_get(&k,&v)==0);
    assert(v.value.integer.value[0]==TAS2555_ERROR_BROWNOUT);
    reset(0,255); p.mnErrorCode=0;
    assert(tas2555_errcode_get(&k,&v)==0 && v.value.integer.value[0]==0);
    puts("PASS: 65536 fault/DSP combinations, fault responses, cached errors, read failures and ALSA error propagation");
    return 0;
}
'''
    with tempfile.TemporaryDirectory(prefix="tas2555-fault-tests-") as temporary:
        source = Path(temporary) / "faults.c"
        binary = Path(temporary) / "faults"
        source.write_text("\n".join(macros) + harness + functions + cases)
        subprocess.run(["cc", "-std=c11", "-Wall", "-Wextra", "-Werror", str(source), "-o", str(binary)], check=True)
        subprocess.run([str(binary)], check=True)


if __name__ == "__main__":
    main()

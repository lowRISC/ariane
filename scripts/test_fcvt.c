#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

uint64_t scan(char *arg, uint64_t rslt[], size_t sz)
{
uint64_t cnt = 0; 
memset(rslt, 0, sz);
while (*arg)
	{
	if (isdigit(*arg)) rslt[cnt] = (rslt[cnt] << 4) | (*arg++ - '0');
	else if (isupper(*arg)) rslt[cnt] = (rslt[cnt] << 4) | (*arg++ - 'A' + 10);
	else if (islower(*arg)) rslt[cnt] = (rslt[cnt] << 4) | (*arg++ - 'a' + 10);
	else 
		{
		arg++;
		cnt++;
		}
	}
return cnt;
}

void testfcvt_dl(int64_t src, int64_t *dstp, int64_t *flagsp)
{
double dst;
int64_t flags;
asm volatile ("fsflags %0,zero": "=r" (flags));
asm ("fcvt.d.l %0,%1,rne": "=f" (dst): "r" (src));
asm ("fsflags %0,zero": "=r" (flags));
*dstp = *(int64_t *)&dst;
*flagsp = flags;
}

void testfcvt_sw(int32_t src, int64_t *dstp, int64_t *flagsp)
{
double dst;
int64_t flags;
asm volatile ("fsflags %0,zero": "=r" (flags));
asm ("fcvt.s.w %0,%1,rne": "=f" (dst): "r" (src));
asm ("fsflags %0,zero": "=r" (flags));
*dstp = *(int64_t *)&dst;
*flagsp = flags;
}

void testfcvt_ld(int64_t src, int64_t *dstp, int64_t *flagsp)
{
int64_t dst, flags;
double srcf = *(double *)&src;
asm volatile ("fsflags %0,zero": "=r" (flags));
asm ("fcvt.l.d %0,%1,rne": "=r" (dst): "f" (srcf));
asm ("fsflags %0,zero": "=r" (flags));
*dstp = dst;
*flagsp = flags;
}

void testfcvt_wd(int64_t src, int64_t *dstp, int64_t *flagsp)
{
int64_t dst, flags;
double srcf = *(double *)&src;
asm volatile ("fsflags %0,zero": "=r" (flags));
asm ("fcvt.w.d %0,%1,rne": "=r" (dst): "f" (srcf));
asm ("fsflags %0,zero": "=r" (flags));
*dstp = dst;
*flagsp = flags;
}

void testfcvt_ds(int64_t src, int64_t *dstp, int64_t *flagsp)
{
int64_t dst, flags;
double rslt;
float srcf = *(float *)&src;
asm volatile ("fsflags %0,zero": "=r" (flags));
asm ("fcvt.d.s %0,%1": "=f" (rslt): "f" (srcf));
asm ("fsflags %0,zero": "=r" (flags));
dst = *(int64_t *)&rslt;
*dstp = dst;
*flagsp = flags;
}

void testfcvt_sd(int64_t src, int64_t *dstp, int64_t *flagsp)
{
int64_t dst, flags;
double srcf = *(double *)&src;
float rsltf;
asm volatile ("fsflags %0,zero": "=r" (flags));
asm ("fcvt.s.d %0,%1,rne": "=f" (rsltf): "f" (srcf));
asm ("fsflags %0,zero": "=r" (flags));
dst = *(int32_t *)&rsltf;
*dstp = dst;
*flagsp = flags;
}

void testfadd_d(int64_t lft, int64_t rght, int64_t *dstp, int64_t *flagsp)
{
int64_t dst, flags;
double lftf = *(double *)&lft;
double rghtf = *(double *)&rght;
double rslt;
asm volatile ("fsflags %0,zero": "=r" (flags));
asm ("fadd.d %0,%1,%2": "=f" (rslt): "f" (lftf), "f" (rghtf));
asm ("fsflags %0,zero": "=r" (flags));
dst = *(int64_t *)&rslt;
*dstp = dst;
*flagsp = flags;
}

void testfsub_d(int64_t lft, int64_t rght, int64_t *dstp, int64_t *flagsp)
{
int64_t dst, flags;
double lftf = *(double *)&lft;
double rghtf = *(double *)&rght;
double rslt;
asm volatile ("fsflags %0,zero": "=r" (flags));
asm ("fsub.d %0,%1,%2": "=f" (rslt): "f" (lftf), "f" (rghtf));
asm ("fsflags %0,zero": "=r" (flags));
dst = *(int64_t *)&rslt;
*dstp = dst;
*flagsp = flags;
}

void testfmul_d(int64_t lft, int64_t rght, int64_t *dstp, int64_t *flagsp)
{
int64_t dst, flags;
double lftf = *(double *)&lft;
double rghtf = *(double *)&rght;
double rslt;
asm volatile ("fsflags %0,zero": "=r" (flags));
asm ("fmul.d %0,%1,%2": "=f" (rslt): "f" (lftf), "f" (rghtf));
asm ("fsflags %0,zero": "=r" (flags));
dst = *(int64_t *)&rslt;
*dstp = dst;
*flagsp = flags;
}

void testfdiv_d(int64_t lft, int64_t rght, int64_t *dstp, int64_t *flagsp)
{
int64_t dst, flags;
double lftf = *(double *)&lft;
double rghtf = *(double *)&rght;
double rslt;
asm volatile ("fsflags %0,zero": "=r" (flags));
asm ("fdiv.d %0,%1,%2": "=f" (rslt): "f" (lftf), "f" (rghtf));
asm ("fsflags %0,zero": "=r" (flags));
dst = *(int64_t *)&rslt;
*dstp = dst;
*flagsp = flags;
}

void testfsqrt_d(int64_t src, int64_t *dstp, int64_t *flagsp)
{
int64_t dst, flags;
double srcf = *(double *)&src;
double rslt;
asm volatile ("fsflags %0,zero": "=r" (flags));
asm ("fsqrt.d %0,%1": "=f" (rslt): "f" (srcf));
asm ("fsflags %0,zero": "=r" (flags));
dst = *(int64_t *)&rslt;
*dstp = dst;
*flagsp = flags;
}

void testfadd_s(int64_t lft, int64_t rght, int64_t *dstp, int64_t *flagsp)
{
int64_t dst, flags;
float lftf = *(float *)&lft;
float rghtf = *(float *)&rght;
int32_t rsltf;
double drslt;
asm volatile ("fsflags %0,zero": "=r" (flags));
asm ("fadd.s %0,%1,%2": "=f" (drslt): "f" (lftf), "f" (rghtf));
asm ("fmv.x.w %0,%1": "=r" (rsltf): "f" (drslt));
asm ("fsflags %0,zero": "=r" (flags));
dst = *(int32_t *)&rsltf;
*dstp = dst;
*flagsp = flags;
}

void testfsub_s(int64_t lft, int64_t rght, int64_t *dstp, int64_t *flagsp)
{
int64_t dst, flags;
float lftf = *(float *)&lft;
float rghtf = *(float *)&rght;
int32_t rsltf;
double drslt;
asm volatile ("fsflags %0,zero": "=r" (flags));
asm ("fsub.s %0,%1,%2": "=f" (drslt): "f" (lftf), "f" (rghtf));
asm ("fmv.x.w %0,%1": "=r" (rsltf): "f" (drslt));
asm ("fsflags %0,zero": "=r" (flags));
dst = *(int32_t *)&rsltf;
*dstp = dst;
*flagsp = flags;
}

void testfmul_s(int64_t lft, int64_t rght, int64_t *dstp, int64_t *flagsp)
{
int64_t dst, flags;
float lftf = *(float *)&lft;
float rghtf = *(float *)&rght;
int32_t rsltf;
double drslt;
asm volatile ("fsflags %0,zero": "=r" (flags));
asm ("fmul.s %0,%1,%2": "=f" (drslt): "f" (lftf), "f" (rghtf));
asm ("fmv.x.w %0,%1": "=r" (rsltf): "f" (drslt));
asm ("fsflags %0,zero": "=r" (flags));
dst = *(int32_t *)&rsltf;
*dstp = dst;
*flagsp = flags;
}

void testfdiv_s(int64_t lft, int64_t rght, int64_t *dstp, int64_t *flagsp)
{
int64_t dst, flags;
float lftf = *(float *)&lft;
float rghtf = *(float *)&rght;
int32_t rsltf;
double drslt;
asm volatile ("fsflags %0,zero": "=r" (flags));
asm ("fdiv.s %0,%1,%2": "=f" (drslt): "f" (lftf), "f" (rghtf));
asm ("fmv.x.w %0,%1": "=r" (rsltf): "f" (drslt));
asm ("fsflags %0,zero": "=r" (flags));
dst = *(int32_t *)&rsltf;
*dstp = dst;
*flagsp = flags;
}

void testfsqrt_s(int64_t src, int64_t *dstp, int64_t *flagsp)
{
int64_t dst, flags;
float srcf = *(float *)&src;
int32_t rsltf;
double drslt;
asm volatile ("fsflags %0,zero": "=r" (flags));
asm ("fsqrt.s %0,%1": "=f" (drslt): "f" (srcf));
asm ("fmv.x.w %0,%1": "=r" (rsltf): "f" (drslt));
asm ("fsflags %0,zero": "=r" (flags));
dst = *(int32_t *)&rsltf;
*dstp = dst;
*flagsp = flags;
}

static struct {
	void (*testf)();
	const char *match;
	int argcnt;
	} fntab[] = {
{ testfcvt_ld, "fcvt_ld", 1 },
{ testfcvt_wd, "fcvt_wd", 1 },
{ testfcvt_dl, "fcvt_dl", 1 },
{ testfcvt_sd, "fcvt_sd", 1 },
{ testfcvt_ds, "fcvt_ds", 1 },
{ testfcvt_sw, "fcvt_sw", 1 },
{ testfadd_d,  "fadd_d", 2 },
{ testfsub_d,  "fsub_d", 2 },
{ testfmul_d,  "fmul_d", 2 },
{ testfdiv_d,  "fdiv_d", 2 },
{ testfsqrt_d, "fsqrt_d", 1 },
{ testfadd_s,  "fadd_s", 2 },
{ testfsub_s,  "fsub_s", 2 },
{ testfmul_s,  "fmul_s", 2 },
{ testfdiv_s,  "fdiv_s", 2 },
{ testfsqrt_s, "fsqrt_s", 1 },
};

int main(int argc, char **argv)
{
int64_t thresh;
char linbuf[256];
if (argc < 2)
	{
	fprintf(stderr, "Usage: %s function\n", argv[0]);
        exit(1);
	}
if (argc > 2)
	{
	thresh = atoll(argv[1]);
	--argc;
	++argv;
	}
else
	thresh = 0;
while (fgets(linbuf, sizeof(linbuf), stdin))
	{
	int cnt;
	uint64_t rslt[8];
	int64_t dst, actdst, actflags, diff;
	cnt = scan(linbuf, rslt, sizeof(rslt));
	if (cnt)
		{
		int found = 0;
		for (int i = 0; i < sizeof(fntab)/sizeof(*fntab); i++)
			if (!strcmp(argv[1], fntab[i].match))
				{
				found = fntab[i].argcnt;
				switch(found)
					{
					case 1: fntab[i].testf(rslt[0], &actdst, &actflags); break;
					case 2: fntab[i].testf(rslt[0], rslt[1], &actdst, &actflags); break;
					case 3: fntab[i].testf(rslt[0], rslt[1], rslt[2], &actdst, &actflags); break;
					}
				found = labs(found);
				}
		if (!found)
			{
			fprintf(stderr, "function %s not found\n", argv[1]);
			for (int i = 0; i < sizeof(fntab)/sizeof(*fntab); i++) puts(fntab[i].match);
			exit(1);
			}
		if (cnt > found)
			{
			if (strstr(argv[1], "_s")) rslt[found] = (int32_t)(rslt[found]);
			if (llabs(actdst - rslt[found]) > thresh)
				{
				for (int i = 0; i < found; i++) printf("%.16llX ", rslt[i]);
				printf("%.16llX %.2llX *%.16llX\n", actdst, actflags, rslt[found]);
				}
			}
		else
			{
			for (int i = 0; i < found; i++) printf("%.16llX ", rslt[i]);
			printf("%.16llX %.2llX\n", actdst, actflags);
			}
		}
	}
}

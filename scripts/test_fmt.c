#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
void header(void)
{
  printf("# See LICENSE for license details.\n");
  printf("\n");
  printf("#*****************************************************************************\n");
  printf("# custom.S\n");
  printf("#-----------------------------------------------------------------------------\n");
  printf("#\n");
  printf("# Test f{add|sub|mul|div}.s instructions.\n");
  printf("#\n");
  printf("\n");
  printf("#include \"riscv_test.h\"\n");
  printf("#include \"test_macros.h\"\n");
  printf("\n");
  printf("RVTEST_RV64UF\n");
  printf("RVTEST_CODE_BEGIN\n");
  printf("\n");
  printf("  #-------------------------------------------------------------\n");
  printf("  # Arithmetic tests\n");
  printf("  #-------------------------------------------------------------\n");
  printf("\n");
  printf("#define TEST_FP_OP_S_CUSTOM( testnum, result, val1, val2, val3, code... ) \\\n");
  printf("test_ ## testnum: \\\n");
  printf("  li  TESTNUM, testnum; \\\n");
  printf("  la  a0, test_ ## testnum ## _data ;\\\n");
  printf("  flw f0, 0(a0); \\\n");
  printf("  flw f1, 4(a0); \\\n");
  printf("  flw f2, 8(a0); \\\n");
  printf("  lw  a3, 12(a0); \\\n");
  printf("  code; \\\n");
  if (0) printf("  bne a0, a3, fail; \\\n");
  printf("  .pushsection .data; \\\n");
  printf("  .align 2; \\\n");
  printf("  test_ ## testnum ## _data: \\\n");
  printf("  .float val1; \\\n");
  printf("  .float val2; \\\n");
  printf("  .float val3; \\\n");
  printf("  .result; \\\n");
  printf("  .popsection\n");
  printf("\n");
  printf("#define TEST_FP_OP2_S_( testnum, inst, result, val1, val2 ) \\\n");
  printf("  TEST_FP_OP_S_CUSTOM( testnum, float result, val1, val2, 0.0, \\\n");
  printf("                    inst f3, f0, f1; fmv.x.s a0, f3)\n");
  printf("\n");
}

void testcase(int cnt, const char *op, int64_t out, int64_t lft, int64_t rght)
{
  float outf = *(float *)&out;
  float lftf = *(float *)&lft;
  float rghtf = *(float *)&rght;
  printf("  TEST_FP_OP2_S_( %d, %s.s, %10.8g, %10.8g, %10.8g );\n", cnt, op, outf, lftf, rghtf);
}

 void footer(void)
 {
  printf("\n");
  printf("  TEST_PASSFAIL\n");
  printf("\n");
  printf("RVTEST_CODE_END\n");
  printf("\n");
  printf("  .data\n");
  printf("RVTEST_DATA_BEGIN\n");
  printf("\n");
  printf("  TEST_DATA\n");
  printf("\n");
  printf("RVTEST_DATA_END\n");
  printf("\n");
}

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

int main(int argc, char **argv)
{
  int cnt, seq = 2;
  char linbuf[256];
  if (argc < 2)
    {
      fprintf(stderr, "Usage: %s function\n", argv[0]);
      exit(1);
    }
  header();
  while (fgets(linbuf, sizeof(linbuf), stdin))
    {
      uint64_t rslt[8];
      int64_t dst, actdst, actflags, diff;
      cnt = scan(linbuf, rslt, sizeof(rslt));
      if (cnt)
	{
	  testcase(seq++, argv[1], rslt[2], rslt[1], rslt[0]);
	}
    }
  footer();
}

#include <stdio.h>
#include <math.h>

int main()
{
  int i;
  printf("   function [51:44] sqlookup;\n");
  printf("      input [8:0] idx;\n");
  printf("\n");
  printf("      begin\n");
  printf("         case(idx)\n");
  for (i = 0; i < 256; i++)
    printf("           %d: sqlookup = %d;\n", i, (int)(floor)(0.5+256.0*(sqrt((256.0+i)/256.0)-1.0)));
  for (i = 256; i < 512; i++)
    printf("           %d: sqlookup = %d;\n", i, (int)(floor)(0.5+256.0*(sqrt((256.0+(i&255))/128.0)-1.0)));
  printf("         endcase\n");
  printf("      end\n");
  printf("\n");
  printf("   endfunction // u1\n");
  printf("\n");
}

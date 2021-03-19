//--------------------------------------------------------------------------------------------------
// Copyright (C) 2013-2017 qiu bin 
// All rights reserved   
// Design    : bitstream_p
// Author(s) : qiu bin
// Email     : chat1@126.com
// Phone 15957074161
// QQ:1517642772             
//-------------------------------------------------------------------------------------------------

//test_pli.c  
#include <stdio.h>
#include <stdlib.h>
#include "veriuser.h"
#include "acc_user.h"
  
FILE* fp;
  
int test_sizetf()  
{  
    return 8;  
}  
   
void func(unsigned char byte, int type )  
{  
	if (!fp && type == 0)
		fp = fopen("out.yuv", "wb");
	else if (fp && type == 1)
		fputc(byte, fp);
	else if (fp && type == 2)
		fflush(fp);
	else if (fp && type == 3)
		fclose(fp);
	else if (!fp && type == 4)
		fp = fopen("out.yuv", "ab");
}  

int test_calltf()  
{  
    int x,y;
    x=tf_getp(1);  
    y=tf_getp(2);  
    func((unsigned char)x, y);  
    return 0;  
}  
  
int test_checktf()  
{  
    char err=0;  
    if(tf_nump()!=2){  
        tf_error("$test requires exactly 2 arguments.\n");  
        err=1;  
    }   
//    if(tf_sizep(1)!=8){  
 //       tf_error("$test's first argument must be 8 bits");  
 //       err=1;  
 //   }  
    if (err) {  
        tf_message(ERR_ERROR, "", "", "");  
    }  
    return(0);  
}  
   

s_tfcell veriusertfs[] =  
{  
    {usertask,      // type of PLI routine - usertask or userfunction  
     0,                 // user_data value  
     test_checktf,      // checktf() routine  
     test_sizetf,       // sizetf() routine  
     test_calltf,       // calltf() routine  
     0,                 // misctf() routine  
     "$fputc"       // "$tfname" system task/function name  
    },  
    {0}                 // final entry must be 0  
};  


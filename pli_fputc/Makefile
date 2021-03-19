MTI_HOME=d:/modeltech64_10.6d
CC=gcc -c -I$(MTI_HOME)/include  
LD=gcc -shared -Bsymbolic 
pli_fputc.dll : pli.c  
	$(CC) pli.c  
	$(LD) -o pli_fputc.dll pli.o  $(MTI_HOME)/win64/mtipli.lib 


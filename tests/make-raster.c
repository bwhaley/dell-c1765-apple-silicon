// Generate a two-page native PWG Raster fixture for an IPP end-to-end test.
#include <cups/raster.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
int main(int argc,char **argv) {
  if(argc!=2 && argc!=3) return 1;
  unsigned scale=argc==3?2:1;
  int fd=open(argv[1],O_CREAT|O_TRUNC|O_WRONLY,0600);
  if(fd<0) return 2;
  cups_raster_t *r=cupsRasterOpen(fd,scale==2?CUPS_RASTER_WRITE_APPLE:CUPS_RASTER_WRITE_PWG);
  cups_page_header2_t h;
  memset(&h,0,sizeof(h));
  h.HWResolution[0]=1200; h.HWResolution[1]=600*scale;
  h.PageSize[0]=612; h.PageSize[1]=792;
  h.cupsPageSize[0]=612; h.cupsPageSize[1]=792;
  h.cupsWidth=10200; h.cupsHeight=6600*scale;
  h.cupsBitsPerColor=8; h.cupsBitsPerPixel=24;
  h.cupsBytesPerLine=30600; h.cupsColorSpace=CUPS_CSPACE_SRGB;
  h.cupsColorOrder=CUPS_ORDER_CHUNKED; h.cupsNumColors=3;
  h.NumCopies=1; strcpy(h.cupsPageSizeName,"na_letter_8.5x11in");
  unsigned char *line=malloc(h.cupsBytesPerLine);
  for(unsigned page=0;page<2;page++) {
    if(!cupsRasterWriteHeader2(r,&h)) return 3;
    for(unsigned y=0;y<h.cupsHeight;y++) {
      memset(line,255,h.cupsBytesPerLine);
      if(y>=600*scale && y<1200*scale) for(unsigned x=1200;x<8400;x++) {
        unsigned color=(x-1200)/1800;
        if(page==1 || color==3) memset(line+3*x,0,3);
        else line[3*x+color]=0; // cyan, magenta, yellow patches
      }
      if(cupsRasterWritePixels(r,line,h.cupsBytesPerLine)!=h.cupsBytesPerLine) return 4;
    }
  }
  free(line); cupsRasterClose(r); close(fd); return 0;
}

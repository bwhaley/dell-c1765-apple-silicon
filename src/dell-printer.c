// Prototype Dell C1765 IPP bridge. Original code licensed under GPL-2.0-or-later.
#include <pappl/pappl.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <sys/file.h>
#include <fcntl.h>
static char encoder_path[PATH_MAX];
static char icon_paths[3][PATH_MAX];
extern char **environ;
typedef struct {
  FILE *input;
  unsigned char *planes;
  unsigned char *average;
  unsigned input_height, input_rows, y_scale;
  unsigned width, height, rows, pages;
  size_t stride, plane_size;
  int paper;
  bool failed;
} job_data;

static bool start_job(pappl_job_t *job, pappl_pr_options_t *o, pappl_device_t *dev) {
  (void)o; (void)dev;
  job_data *d = calloc(1, sizeof(*d));
  if (!d) return false;
  d->input = tmpfile();
  if (!d->input) { free(d); return false; }
  papplJobSetData(job, d);
  return true;
}

static bool start_page(pappl_job_t *job, pappl_pr_options_t *o, pappl_device_t *dev, unsigned page) {
  (void)dev; (void)page;
  job_data *d = papplJobGetData(job);
  int paper = !strcmp(o->media.size_name, "iso_a4_210x297mm") ? 1 : 4;
  if (d->pages && paper != d->paper) return !(d->failed = true);
  d->paper = paper;
  d->width = o->header.cupsWidth;
  d->input_height = o->header.cupsHeight;
  d->input_rows = 0;
  if (o->header.HWResolution[0] != 1200 ||
      (o->header.HWResolution[1] != 600 && o->header.HWResolution[1] != 1200)) {
    papplLogJob(job,PAPPL_LOGLEVEL_ERROR,"Unsupported raster resolution %ux%u",o->header.HWResolution[0],o->header.HWResolution[1]);
    return !(d->failed = true);
  }
  d->y_scale = o->header.HWResolution[1] / 600;
  d->height = (d->input_height + d->y_scale - 1) / d->y_scale;
  if (!d->width || !d->height || d->width > 11000 || d->height > 7100 || d->pages >= 100)
    return !(d->failed = true);
  d->stride = (d->width + 7) / 8;
  d->plane_size = d->stride * d->height;
  d->planes = calloc(4, d->plane_size);
  d->average = malloc(o->header.cupsBytesPerLine);
  d->rows = 0;
  if (!d->planes || !d->average) return !(d->failed = true);
  return true;
}

static bool write_line(pappl_job_t *job, pappl_pr_options_t *o, pappl_device_t *dev, unsigned y, const unsigned char *line) {
  (void)dev;
  job_data *d = papplJobGetData(job);
  static const unsigned char bayer[4][4] = {{0,8,2,10},{12,4,14,6},{3,11,1,9},{15,7,13,5}};
  if (y >= d->input_height || y != d->input_rows) return !(d->failed = true);
  d->input_rows++;
  if (d->y_scale == 2 && o->header.cupsBitsPerColor == 8) {
    if (y % 2 == 0) {
      memcpy(d->average,line,o->header.cupsBytesPerLine);
      if (y + 1 < d->input_height) return true;
    } else {
      for (unsigned i=0;i<o->header.cupsBytesPerLine;i++)
        d->average[i]=(unsigned char)(((unsigned)d->average[i]+line[i]+1)/2);
    }
    line=d->average;
  } else if (d->y_scale == 2 && y % 2) return true;
  y /= d->y_scale;
  for (unsigned x = 0; x < d->width; x++) {
    int c=0, m=0, yellow=0, k=0;
    if (o->header.cupsColorSpace == CUPS_CSPACE_SRGB && o->header.cupsBitsPerPixel == 24) {
      c=255-line[3*x]; m=255-line[3*x+1]; yellow=255-line[3*x+2];
      k=c<m?c:m; if (yellow<k) k=yellow;
      c-=k; m-=k; yellow-=k;
      if (o->print_color_mode == PAPPL_COLOR_MODE_MONOCHROME) {
        k=255-(77*line[3*x]+150*line[3*x+1]+29*line[3*x+2]+128)/256;
        c=m=yellow=0;
      }
    } else if (o->header.cupsColorSpace == CUPS_CSPACE_SW && o->header.cupsBitsPerPixel == 8) {
      k=255-line[x];
    } else if (o->header.cupsColorSpace == CUPS_CSPACE_K && o->header.cupsBitsPerPixel == 8) {
      k=line[x];
    } else if (o->header.cupsColorSpace == CUPS_CSPACE_K && o->header.cupsBitsPerPixel == 1) {
      k=(line[x/8] & (128 >> (x%8))) ? 255 : 0;
    } else return !(d->failed = true);
    int values[4]={c,m,yellow,k};
    int threshold=8+16*bayer[y%4][x%4];
    for (int p=0;p<4;p++) if (values[p] > threshold)
      d->planes[p*d->plane_size+y*d->stride+x/8] |= 128 >> (x%8);
  }
  d->rows++;
  return true;
}

static bool end_page(pappl_job_t *job, pappl_pr_options_t *o, pappl_device_t *dev, unsigned page) {
  (void)o; (void)dev; (void)page;
  job_data *d=papplJobGetData(job);
  if (d->rows != d->height || d->input_rows != d->input_height) d->failed=true;
  for (int p=0;p<4 && !d->failed;p++) {
    if (fprintf(d->input,"P4\n%u %u\n",d->width,d->height)<0 ||
        fwrite(d->planes+p*d->plane_size,1,d->plane_size,d->input)!=d->plane_size) d->failed=true;
  }
  free(d->planes); d->planes=NULL; free(d->average); d->average=NULL; d->pages++;
  return !d->failed;
}

static bool end_job(pappl_job_t *job, pappl_pr_options_t *o, pappl_device_t *dev) {
  (void)o;
  job_data *d=papplJobGetData(job);
  if (!d) return false;
  bool ok=!d->failed && d->pages && !d->planes && !papplJobIsCanceled(job);
  FILE *output=NULL;
  if (ok) {
    output=tmpfile();
    ok=output && !fflush(d->input) && !fseek(d->input,0,SEEK_SET);
  }
  if (ok) {
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_adddup2(&actions,fileno(d->input),STDIN_FILENO);
    posix_spawn_file_actions_adddup2(&actions,fileno(output),STDOUT_FILENO);
    char *args[]={encoder_path,"-c","-r1200x600","-p",d->paper==1?"1":"4","-s","7",NULL};
    pid_t pid; int status=0;
    int err=posix_spawn(&pid,encoder_path,&actions,NULL,args,environ);
    posix_spawn_file_actions_destroy(&actions);
    if (err) ok=false;
    else {
      pid_t result;
      do { result=waitpid(pid,&status,0); } while (result<0 && errno==EINTR);
      ok=result==pid && WIFEXITED(status) && WEXITSTATUS(status)==0;
    }
    if (ok) {
      rewind(output);
      unsigned char buf[16384]; size_t n;
      while (ok && (n=fread(buf,1,sizeof(buf),output))>0) {
        if (papplJobIsCanceled(job)) { ok=false; break; }
        size_t sent=0;
        while (sent<n) {
          ssize_t written=papplDeviceWrite(dev,buf+sent,n-sent);
          if (written<=0) { ok=false; break; }
          sent+=(size_t)written;
        }
      }
      if (ferror(output)) ok=false;
    }
  }
  if (!ok) papplLogJob(job,PAPPL_LOGLEVEL_ERROR,"Job conversion or delivery failed; see service log.");
  if (output) fclose(output);
  fclose(d->input); free(d->planes); free(d->average); free(d); papplJobSetData(job,NULL);
  return ok;
}

static bool driver(pappl_system_t *system,const char *name,const char *uri,const char *id,
                   pappl_pr_driver_data_t *d,ipp_t **attrs,void *data) {
  (void)system;(void)name;(void)uri;(void)id;(void)attrs;(void)data;
  for (int i=0;i<3;i++)
    if (!access(icon_paths[i],R_OK) && strlen(icon_paths[i])<sizeof(d->icons[i].filename))
      papplCopyString(d->icons[i].filename,icon_paths[i],sizeof(d->icons[i].filename));
  papplCopyString(d->make_and_model,"Dell C1765nfw Native (Prototype)",sizeof(d->make_and_model));
  d->format=NULL; // Accept raster input only; do not expose raw-job passthrough.
  d->rstartjob_cb=start_job; d->rstartpage_cb=start_page;
  d->rwriteline_cb=write_line; d->rendpage_cb=end_page; d->rendjob_cb=end_job;
  d->raster_types=PAPPL_PWG_RASTER_TYPE_SRGB_8|PAPPL_PWG_RASTER_TYPE_SGRAY_8|PAPPL_PWG_RASTER_TYPE_BLACK_1;
  d->color_supported=PAPPL_COLOR_MODE_COLOR|PAPPL_COLOR_MODE_MONOCHROME;
  d->color_default=PAPPL_COLOR_MODE_COLOR;
  d->num_resolution=1; d->x_resolution[0]=d->x_default=1200; d->y_resolution[0]=d->y_default=600;
  d->num_media=2; d->media[0]="na_letter_8.5x11in"; d->media[1]="iso_a4_210x297mm";
  d->left_right=d->bottom_top=423;
  papplCopyString(d->media_default.size_name,d->media[0],sizeof(d->media_default.size_name));
  d->num_source=1; d->source[0]="main";
  d->num_type=1; d->type[0]="stationery";
  d->sides_supported=d->sides_default=PAPPL_SIDES_ONE_SIDED;
  d->quality_default=IPP_QUALITY_NORMAL;
  d->kind=PAPPL_KIND_DOCUMENT;
  d->ppm=15; d->ppm_color=12;
  return true;
}

int main(int argc,char **argv) {
  // Hold the lock for the server lifetime; do not permit duplicate listeners
  // or multiple processes writing the same state file.
  for (int i=1;i<argc;i++) if (!strcmp(argv[i],"server")) {
    char lockpath[128];
    snprintf(lockpath,sizeof(lockpath),"/tmp/dell-native-%u.lock",(unsigned)getuid());
    int fd=open(lockpath,O_CREAT|O_RDWR|O_NOFOLLOW|O_CLOEXEC,0600);
    if (fd<0 || flock(fd,LOCK_EX|LOCK_NB)) {
      fprintf(stderr,"Another Dell Native service is running, or its lock is unavailable.\n"); return 1;
    }
    break;
  }
  char executable[PATH_MAX]; uint32_t size=sizeof(executable);
  if (_NSGetExecutablePath(executable,&size) || !realpath(executable,encoder_path)) return 1;
  char *slash=strrchr(encoder_path,'/');
  if (!slash || (size_t)(slash-encoder_path)+sizeof("/foo2hbpl2")>sizeof(encoder_path)) return 1;
  static const char *icon_names[]={"icon-sm.png","icon-md.png","icon-lg.png"};
  for (int i=0;i<3;i++)
    snprintf(icon_paths[i],sizeof(icon_paths[i]),"%.*s/../icons/%s",(int)(slash-encoder_path),encoder_path,icon_names[i]);
  strcpy(slash,"/foo2hbpl2");
  if (access(encoder_path,X_OK)) { fprintf(stderr,"Missing sibling foo2hbpl2 encoder\n"); return 1; }
  static pappl_pr_driver_t drivers[]={{"dell-c1765","Dell C1765nfw Native (Prototype)",NULL,NULL}};
  return papplMainloop(argc,argv,DELL_VERSION,"Dell C1765 native printing",1,drivers,NULL,driver,NULL,NULL,NULL,NULL,NULL);
}

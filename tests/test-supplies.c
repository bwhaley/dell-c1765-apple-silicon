// Exercise the actual driver callback with a fake device; no network or paper.
#include <assert.h>
#define papplPrinterGetDeviceURI test_uri
#define papplPrinterOpenDevice test_open
#define papplDeviceGetSupplies test_read
#define papplPrinterGetSupplies test_cached
#define papplPrinterSetSupplies test_publish
#define papplPrinterCloseDevice test_close
#define main dell_main
#include "../src/dell-printer.c"
#undef main

static const char *uri = "socket://printer.example:9100";
static int opened, closed, published, count = 4, cached_count;
static bool busy;
static pappl_supply_t readings[PAPPL_MAX_SUPPLY], cached[PAPPL_MAX_SUPPLY];
const char *test_uri(pappl_printer_t *p) { (void)p; return uri; }
pappl_device_t *test_open(pappl_printer_t *p) {
  (void)p; opened++; return busy ? NULL : (pappl_device_t *)&opened;
}
int test_read(pappl_device_t *d, int max, pappl_supply_t *s) {
  (void)d; memcpy(s, readings, sizeof(*s) * (size_t)(count > max ? max : count > 0 ? count : 0));
  return count;
}
int test_cached(pappl_printer_t *p, int max, pappl_supply_t *s) {
  (void)p; assert(cached_count <= max);
  memcpy(s, cached, sizeof(*s) * (size_t)cached_count); return cached_count;
}
void test_publish(pappl_printer_t *p, int n, pappl_supply_t *s) {
  (void)p; assert(n >= 0 && n <= PAPPL_MAX_SUPPLY); published++;
  cached_count = n; memcpy(cached, s, sizeof(*s) * (size_t)n);
}
void test_close(pappl_printer_t *p) { (void)p; closed++; }

int main(void) {
  pappl_printer_t *p = (pappl_printer_t *)&opened;
  pappl_pr_driver_data_t data = {0};
  assert(driver(NULL, NULL, NULL, NULL, &data, NULL, NULL));
  assert(data.has_supplies && data.status_cb == update_supplies);
  int levels[] = {100, 37, 0, -1};
  for (int i = 0; i < 4; i++) {
    readings[i].level = levels[i]; readings[i].type = PAPPL_SUPPLY_TYPE_TONER;
    readings[i].is_consumed = true;
    snprintf(readings[i].description, sizeof(readings[i].description), "Toner %d", i);
  }
  assert(update_supplies(p));
  assert(cached_count == 4 && !memcmp(cached, readings, 4 * sizeof(*cached)));
  assert(opened == 1 && closed == 1);
  // Missing SNMP must replace cached percentages with unknown, retaining names.
  count = 0;
  assert(!update_supplies(p));
  for (int i = 0; i < 4; i++) {
    assert(cached[i].level == -1);
    assert(!strcmp(cached[i].description, readings[i].description));
  }
  assert(opened == closed);
  count = 4;
  assert(update_supplies(p)); // Recovery updates the same cartridges.
  assert(cached[1].level == 37);
  busy = true;
  int before = published, closes_before = closed;
  assert(!update_supplies(p));
  assert(published == before && closed == closes_before && cached[1].level == 37);
  busy = false;
  uri = "file:///tmp/capture.hbpl";
  int opens_before = opened;
  assert(update_supplies(p));
  uri = NULL; assert(update_supplies(p));
  assert(opened == opens_before && published == before);
  uri = "dnssd://printer.example"; count = PAPPL_MAX_SUPPLY + 1;
  assert(update_supplies(p) && cached_count == PAPPL_MAX_SUPPLY);
  uri = "snmp://printer.example"; count = -1; cached_count = 0;
  assert(!update_supplies(p) && cached_count == 0);
  puts("Supply callback tests passed.");
  return 0;
}

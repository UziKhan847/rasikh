#include <stdlib.h>

#include "my_application.h"

int main(int argc, char** argv) {
  // Works around a confirmed Flutter Linux engine bug (flutter/flutter#153560):
  // focusing a TextField makes the engine push an accessibility-tree update,
  // and GTK's AT-SPI bridge (libatk-bridge-2.0) answers with a SYNCHRONOUS
  // D-Bus round trip on this thread — the one running the GTK main loop,
  // Flutter's platform channels, and the window itself. On setups where
  // nothing answers that D-Bus call (several GNOME/Cinnamon + AT-SPI
  // combinations), the call blocks for the full 25-second D-Bus timeout,
  // freezing the whole app solid on every focus change. Confirmed via GDB
  // by another reporter on that issue: the block sits in
  // fl_accessible_node_get_extents -> atk_component_get_extents ->
  // dbus_connection_send_with_reply_and_block, still present as of the
  // current engine (no fix has landed upstream).
  //
  // NO_AT_BRIDGE=1 tells GTK to skip loading the AT-SPI bridge for this
  // process entirely, which is the confirmed fix — but it also means this
  // Linux build cannot be driven by a screen reader. That trade is fine here:
  // Linux is a desktop dev-iteration target for this app, not a shipped
  // platform (Android/iOS are, and neither touches this file or GTK's
  // accessibility bridge at all). setenv's overwrite=0 leaves a
  // developer's own NO_AT_BRIDGE=0 (to explicitly test the bridge) alone.
  setenv("NO_AT_BRIDGE", "1", 0);

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}

//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <charset_converter/charset_converter_plugin.h>
#include <windows_printer/windows_printer_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  CharsetConverterPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("CharsetConverterPlugin"));
  WindowsPrinterPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WindowsPrinterPluginCApi"));
}

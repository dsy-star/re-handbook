// probe.js — 只读探针：不改行为，只报告环境与已加载类规模。
// 用法: run-frida.sh -p <pkg> -l hooks/probe.js
Java.perform(function () {
  var app = null;
  try {
    app = Java.use('android.app.ActivityThread').currentApplication();
    console.log('[probe] application = ' + (app ? app.getPackageName() : 'null'));
  } catch (e) {
    console.log('[probe] ActivityThread 不可用: ' + e);
  }
  try {
    var loader = app ? app.getClassLoader() : null;
    if (loader) {
      Java.enumerateLoadedClasses({ onMatch: function () {}, onComplete: function () {} });
      console.log('[probe] ClassLoader = ' + loader);
    }
  } catch (e) { console.log('[probe] loader: ' + e); }
  try {
    var n = 0;
    Java.enumerateLoadedClassesSync().forEach(function (c) { if (c.indexOf('.') > 0) n++; });
    console.log('[probe] loaded classes = ' + n);
  } catch (e) { console.log('[probe] enumerate: ' + e); }
  ['libc.so', 'libart.so', 'libnative.so'].forEach(function (m) {
    var mod = Process.findModuleByName(m);
    console.log('[probe] module ' + m + ' = ' + (mod ? mod.base + ' size=' + mod.size : 'not loaded'));
  });
});

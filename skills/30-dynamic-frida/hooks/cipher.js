// cipher.js — 加密调用观测模板：只打印算法/输入/输出，不改返回值。
// 用法: run-frida.sh -p <pkg> -l hooks/cipher.js
function hex(b) {
  if (!b) return 'null';
  var a = Java.array('byte', b), s = '';
  for (var i = 0; i < a.length && i < 64; i++) {
    var v = (a[i] & 0xff).toString(16); s += (v.length < 2 ? '0' : '') + v;
  }
  return s + (a.length > 64 ? '…(' + a.length + 'B)' : '');
}
Java.perform(function () {
  try {
    var Cipher = Java.use('javax.crypto.Cipher');
    Cipher.doFinal.overload('[B').implementation = function (input) {
      var algo = '?';
      try { algo = this.getAlgorithm(); } catch (e) {}
      console.log('[cipher] algo=' + algo + ' in=' + hex(input));
      var out = this.doFinal(input);
      console.log('[cipher] out=' + hex(out));
      return out;
    };
    console.log('[cipher] hooked Cipher.doFinal([B)');
  } catch (e) { console.log('[cipher] Cipher hook failed: ' + e); }

  try {
    var MD = Java.use('java.security.MessageDigest');
    MD.digest.overload('[B').implementation = function (input) {
      var out = this.digest(input);
      console.log('[digest] ' + this.getAlgorithm() + ' in=' + hex(input) + ' out=' + hex(out));
      return out;
    };
    console.log('[cipher] hooked MessageDigest.digest([B)');
  } catch (e) { console.log('[cipher] MessageDigest hook failed: ' + e); }
});

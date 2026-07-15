/* awg_qr.js — self-contained helpers for the AmneziaWG Server page.
 *
 * 1) AWGQR  — QR Code generator (byte mode, versions 1-40, ECC auto-boost, auto mask).
 *    A compact port of Project Nayuki's qrcodegen (MIT). No DOM/network dependencies;
 *    returns a module matrix + an SVG-path renderer. Served from /www/user (router httpd),
 *    used by the page to render peer configs as scannable QR codes fully client-side.
 *
 * 2) AWGKeys — WireGuard-style key material in the browser (Curve25519):
 *    genPrivkey(): random clamped scalar (b64);  pubFromPriv(b64): X25519 base-point mult
 *    (tweetnacl-derived field math, public domain);  genPsk(): 32 random bytes (b64).
 *    Private keys are generated locally and go ONLY into custom_settings via the normal
 *    Apply POST — the same trust model as the client page's own key fields.
 */
(function(){
"use strict";

/* ===================== QR code generator (port of Nayuki qrcodegen, MIT) ===================== */

var ECC = { L: {ordinal: 0, formatBits: 1},
            M: {ordinal: 1, formatBits: 0},
            Q: {ordinal: 2, formatBits: 3},
            H: {ordinal: 3, formatBits: 2} };

var ECC_CODEWORDS_PER_BLOCK = [
  // 1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40
  [-1, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],  // L
  [-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28],  // M
  [-1, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30, 28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],  // Q
  [-1, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26, 28, 30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30]   // H
];
var NUM_ERROR_CORRECTION_BLOCKS = [
  [-1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, 9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25],   // L
  [-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49],  // M
  [-1, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, 20, 23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68], // Q
  [-1, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25, 25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81]  // H
];

function getNumRawDataModules(ver){
  if (ver < 1 || ver > 40) throw "Version out of range";
  var result = (16 * ver + 128) * ver + 64;
  if (ver >= 2) {
    var numAlign = Math.floor(ver / 7) + 2;
    result -= (25 * numAlign - 10) * numAlign - 55;
    if (ver >= 7) result -= 36;
  }
  return result;
}

function getNumDataCodewords(ver, ecl){
  return Math.floor(getNumRawDataModules(ver) / 8) -
    ECC_CODEWORDS_PER_BLOCK[ecl.ordinal][ver] *
    NUM_ERROR_CORRECTION_BLOCKS[ecl.ordinal][ver];
}

/* --- GF(256) Reed-Solomon (poly 0x11D) --- */
function rsMultiply(x, y){
  var z = 0;
  for (var i = 7; i >= 0; i--) {
    z = (z << 1) ^ ((z >>> 7) * 0x11D);
    z ^= ((y >>> i) & 1) * x;
  }
  return z & 0xFF;
}
function rsComputeDivisor(degree){
  var result = [];
  for (var i = 0; i < degree - 1; i++) result.push(0);
  result.push(1);              // x^(degree-1) coefficient list, highest power first implied
  var root = 1;
  for (var j = 0; j < degree; j++) {
    for (var k = 0; k < result.length; k++) {
      result[k] = rsMultiply(result[k], root);
      if (k + 1 < result.length) result[k] ^= result[k + 1];
    }
    root = rsMultiply(root, 0x02);
  }
  return result;
}
function rsComputeRemainder(data, divisor){
  var result = divisor.map(function(){ return 0; });
  for (var i = 0; i < data.length; i++) {
    var factor = data[i] ^ result.shift();
    result.push(0);
    for (var j = 0; j < divisor.length; j++)
      result[j] ^= rsMultiply(divisor[j], factor);
  }
  return result;
}

/* --- Bit buffer --- */
function BitBuffer(){ this.bits = []; }
BitBuffer.prototype.appendBits = function(val, len){
  if (len < 0 || len > 31 || (val >>> len) !== 0) throw "Value out of range";
  for (var i = len - 1; i >= 0; i--) this.bits.push((val >>> i) & 1);
};

/* --- The QR symbol --- */
function QrCode(version, ecl, dataCodewords, msk){
  this.version = version;
  this.size = version * 4 + 17;
  this.errorCorrectionLevel = ecl;
  var row = [], i;
  for (i = 0; i < this.size; i++) row.push(false);
  this.modules = [];
  this.isFunction = [];
  for (i = 0; i < this.size; i++) {
    this.modules.push(row.slice());
    this.isFunction.push(row.slice());
  }
  this.drawFunctionPatterns();
  var allCodewords = this.addEccAndInterleave(dataCodewords);
  this.drawCodewords(allCodewords);
  if (msk === -1) {   // automatic mask by minimum penalty
    var minPenalty = 1000000000;
    for (i = 0; i < 8; i++) {
      this.applyMask(i);
      this.drawFormatBits(i);
      var penalty = this.getPenaltyScore();
      if (penalty < minPenalty) { msk = i; minPenalty = penalty; }
      this.applyMask(i);  // undo (XOR)
    }
  }
  this.mask = msk;
  this.applyMask(msk);
  this.drawFormatBits(msk);
  this.isFunction = null;
}

QrCode.prototype.getModule = function(x, y){
  return x >= 0 && x < this.size && y >= 0 && y < this.size && this.modules[y][x];
};

QrCode.prototype.setFunctionModule = function(x, y, isDark){
  this.modules[y][x] = isDark;
  this.isFunction[y][x] = true;
};

QrCode.prototype.drawFunctionPatterns = function(){
  var i;
  for (i = 0; i < this.size; i++) {          // timing patterns
    this.setFunctionModule(6, i, i % 2 === 0);
    this.setFunctionModule(i, 6, i % 2 === 0);
  }
  this.drawFinderPattern(3, 3);
  this.drawFinderPattern(this.size - 4, 3);
  this.drawFinderPattern(3, this.size - 4);
  var alignPatPos = this.getAlignmentPatternPositions();
  var numAlign = alignPatPos.length;
  for (i = 0; i < numAlign; i++) {
    for (var j = 0; j < numAlign; j++) {
      if (!(i === 0 && j === 0 || i === 0 && j === numAlign - 1 || i === numAlign - 1 && j === 0))
        this.drawAlignmentPattern(alignPatPos[i], alignPatPos[j]);
    }
  }
  this.drawFormatBits(0);   // dummy value; overwritten after masking
  this.drawVersion();
};

QrCode.prototype.drawFormatBits = function(msk){
  var data = this.errorCorrectionLevel.formatBits << 3 | msk;
  var rem = data;
  for (var i = 0; i < 10; i++) rem = (rem << 1) ^ ((rem >>> 9) * 0x537);
  var bits = (data << 10 | rem) ^ 0x5412;
  for (i = 0; i <= 5; i++) this.setFunctionModule(8, i, getBit(bits, i));
  this.setFunctionModule(8, 7, getBit(bits, 6));
  this.setFunctionModule(8, 8, getBit(bits, 7));
  this.setFunctionModule(7, 8, getBit(bits, 8));
  for (i = 9; i < 15; i++) this.setFunctionModule(14 - i, 8, getBit(bits, i));
  for (i = 0; i < 8; i++) this.setFunctionModule(this.size - 1 - i, 8, getBit(bits, i));
  for (i = 8; i < 15; i++) this.setFunctionModule(8, this.size - 15 + i, getBit(bits, i));
  this.setFunctionModule(8, this.size - 8, true);   // always dark
};

QrCode.prototype.drawVersion = function(){
  if (this.version < 7) return;
  var rem = this.version;
  for (var i = 0; i < 12; i++) rem = (rem << 1) ^ ((rem >>> 11) * 0x1F25);
  var bits = this.version << 12 | rem;
  for (i = 0; i < 18; i++) {
    var color = getBit(bits, i);
    var a = this.size - 11 + i % 3;
    var b = Math.floor(i / 3);
    this.setFunctionModule(a, b, color);
    this.setFunctionModule(b, a, color);
  }
};

QrCode.prototype.drawFinderPattern = function(x, y){
  for (var dy = -4; dy <= 4; dy++) {
    for (var dx = -4; dx <= 4; dx++) {
      var dist = Math.max(Math.abs(dx), Math.abs(dy));
      var xx = x + dx, yy = y + dy;
      if (xx >= 0 && xx < this.size && yy >= 0 && yy < this.size)
        this.setFunctionModule(xx, yy, dist !== 2 && dist !== 4);
    }
  }
};

QrCode.prototype.drawAlignmentPattern = function(x, y){
  for (var dy = -2; dy <= 2; dy++)
    for (var dx = -2; dx <= 2; dx++)
      this.setFunctionModule(x + dx, y + dy, Math.max(Math.abs(dx), Math.abs(dy)) !== 1);
};

QrCode.prototype.getAlignmentPatternPositions = function(){
  if (this.version === 1) return [];
  var numAlign = Math.floor(this.version / 7) + 2;
  var step = (this.version === 32) ? 26 :
    Math.ceil((this.version * 4 + 4) / (numAlign * 2 - 2)) * 2;
  var result = [6];
  for (var pos = this.size - 7; result.length < numAlign; pos -= step)
    result.splice(1, 0, pos);
  return result;
};

QrCode.prototype.addEccAndInterleave = function(data){
  var ver = this.version;
  var ecl = this.errorCorrectionLevel;
  if (data.length !== getNumDataCodewords(ver, ecl)) throw "Invalid argument";
  var numBlocks = NUM_ERROR_CORRECTION_BLOCKS[ecl.ordinal][ver];
  var blockEccLen = ECC_CODEWORDS_PER_BLOCK[ecl.ordinal][ver];
  var rawCodewords = Math.floor(getNumRawDataModules(ver) / 8);
  var numShortBlocks = numBlocks - rawCodewords % numBlocks;
  var shortBlockLen = Math.floor(rawCodewords / numBlocks);

  var blocks = [];
  var rsDiv = rsComputeDivisor(blockEccLen);
  for (var i = 0, k = 0; i < numBlocks; i++) {
    var dat = data.slice(k, k + shortBlockLen - blockEccLen + (i < numShortBlocks ? 0 : 1));
    k += dat.length;
    var ecc = rsComputeRemainder(dat, rsDiv);
    if (i < numShortBlocks) dat.push(0);
    blocks.push(dat.concat(ecc));
  }
  var result = [];
  for (i = 0; i < blocks[0].length; i++) {
    for (var j = 0; j < blocks.length; j++) {
      if (i !== shortBlockLen - blockEccLen || j >= numShortBlocks)
        result.push(blocks[j][i]);
    }
  }
  return result;
};

QrCode.prototype.drawCodewords = function(data){
  if (data.length !== Math.floor(getNumRawDataModules(this.version) / 8)) throw "Invalid argument";
  var i = 0;
  for (var right = this.size - 1; right >= 1; right -= 2) {
    if (right === 6) right = 5;
    for (var vert = 0; vert < this.size; vert++) {
      for (var j = 0; j < 2; j++) {
        var x = right - j;
        var upward = ((right + 1) & 2) === 0;
        var y = upward ? this.size - 1 - vert : vert;
        if (!this.isFunction[y][x] && i < data.length * 8) {
          this.modules[y][x] = getBit(data[i >>> 3], 7 - (i & 7));
          i++;
        }
      }
    }
  }
};

QrCode.prototype.applyMask = function(msk){
  for (var y = 0; y < this.size; y++) {
    for (var x = 0; x < this.size; x++) {
      var invert;
      switch (msk) {
        case 0: invert = (x + y) % 2 === 0; break;
        case 1: invert = y % 2 === 0; break;
        case 2: invert = x % 3 === 0; break;
        case 3: invert = (x + y) % 3 === 0; break;
        case 4: invert = (Math.floor(x / 3) + Math.floor(y / 2)) % 2 === 0; break;
        case 5: invert = x * y % 2 + x * y % 3 === 0; break;
        case 6: invert = (x * y % 2 + x * y % 3) % 2 === 0; break;
        case 7: invert = ((x + y) % 2 + x * y % 3) % 2 === 0; break;
        default: throw "Unreachable";
      }
      if (!this.isFunction[y][x] && invert) this.modules[y][x] = !this.modules[y][x];
    }
  }
};

QrCode.prototype.getPenaltyScore = function(){
  var result = 0;
  var size = this.size;
  var PENALTY_N1 = 3, PENALTY_N2 = 3, PENALTY_N3 = 40, PENALTY_N4 = 10;
  var x, y, runColor, runX, runY, runHistory;

  for (y = 0; y < size; y++) {              // rows: adjacent runs + finder-like
    runColor = false; runX = 0; runHistory = [0,0,0,0,0,0,0];
    for (x = 0; x < size; x++) {
      if (this.modules[y][x] === runColor) {
        runX++;
        if (runX === 5) result += PENALTY_N1;
        else if (runX > 5) result++;
      } else {
        this.finderPenaltyAddHistory(runX, runHistory);
        if (!runColor) result += this.finderPenaltyCountPatterns(runHistory) * PENALTY_N3;
        runColor = this.modules[y][x];
        runX = 1;
      }
    }
    result += this.finderPenaltyTerminateAndCount(runColor, runX, runHistory) * PENALTY_N3;
  }
  for (x = 0; x < size; x++) {              // columns
    runColor = false; runY = 0; runHistory = [0,0,0,0,0,0,0];
    for (y = 0; y < size; y++) {
      if (this.modules[y][x] === runColor) {
        runY++;
        if (runY === 5) result += PENALTY_N1;
        else if (runY > 5) result++;
      } else {
        this.finderPenaltyAddHistory(runY, runHistory);
        if (!runColor) result += this.finderPenaltyCountPatterns(runHistory) * PENALTY_N3;
        runColor = this.modules[y][x];
        runY = 1;
      }
    }
    result += this.finderPenaltyTerminateAndCount(runColor, runY, runHistory) * PENALTY_N3;
  }
  for (y = 0; y < size - 1; y++) {          // 2x2 blocks
    for (x = 0; x < size - 1; x++) {
      var color = this.modules[y][x];
      if (color === this.modules[y][x + 1] &&
          color === this.modules[y + 1][x] &&
          color === this.modules[y + 1][x + 1])
        result += PENALTY_N2;
    }
  }
  var dark = 0;                              // balance
  for (y = 0; y < size; y++)
    for (x = 0; x < size; x++)
      if (this.modules[y][x]) dark++;
  var total = size * size;
  var k = Math.ceil(Math.abs(dark * 20 - total * 10) / total) - 1;
  result += k * PENALTY_N4;
  return result;
};

QrCode.prototype.finderPenaltyCountPatterns = function(runHistory){
  var n = runHistory[1];
  var core = n > 0 && runHistory[2] === n && runHistory[3] === n * 3 &&
             runHistory[4] === n && runHistory[5] === n;
  return (core && runHistory[0] >= n * 4 && runHistory[6] >= n ? 1 : 0) +
         (core && runHistory[6] >= n * 4 && runHistory[0] >= n ? 1 : 0);
};
QrCode.prototype.finderPenaltyTerminateAndCount = function(currentRunColor, currentRunLength, runHistory){
  if (currentRunColor) {
    this.finderPenaltyAddHistory(currentRunLength, runHistory);
    currentRunLength = 0;
  }
  currentRunLength += this.size;   // light border padding
  this.finderPenaltyAddHistory(currentRunLength, runHistory);
  return this.finderPenaltyCountPatterns(runHistory);
};
QrCode.prototype.finderPenaltyAddHistory = function(currentRunLength, runHistory){
  if (runHistory[0] === 0) currentRunLength += this.size;
  runHistory.pop();
  runHistory.unshift(currentRunLength);
};

function getBit(x, i){ return ((x >>> i) & 1) !== 0; }

/* --- Byte-mode encode: UTF-8 the text, pick min version, boost ECC, build codewords --- */
function encodeText(text, preferEcl){
  // UTF-8 bytes
  var bytes = [];
  var enc = unescape(encodeURIComponent(text));
  for (var i = 0; i < enc.length; i++) bytes.push(enc.charCodeAt(i) & 0xFF);

  var ecl = preferEcl || ECC.M;
  var version, dataUsedBits = -1;
  for (version = 1; version <= 40; version++) {
    var dataCapacityBits0 = getNumDataCodewords(version, ecl) * 8;
    var ccBits = version <= 9 ? 8 : 16;               // byte-mode char-count width
    var need = 4 + ccBits + bytes.length * 8;
    if (need <= dataCapacityBits0) { dataUsedBits = need; break; }
    if (version === 40) {
      if (ecl !== ECC.L) { ecl = ECC.L; version = 0; continue; }  // step down once, rescan
      throw "Data too long";
    }
  }
  // Boost ECC within the same version (Nayuki's boostEcl) — bigger scan margin for free.
  var levels = [ECC.M, ECC.Q, ECC.H];
  for (i = 0; i < levels.length; i++) {
    if (ecl.ordinal < levels[i].ordinal &&
        dataUsedBits <= getNumDataCodewords(version, levels[i]) * 8)
      ecl = levels[i];
  }

  var bb = new BitBuffer();
  bb.appendBits(4, 4);                                  // byte mode
  bb.appendBits(bytes.length, version <= 9 ? 8 : 16);   // char count
  for (i = 0; i < bytes.length; i++) bb.appendBits(bytes[i], 8);

  var dataCapacityBits = getNumDataCodewords(version, ecl) * 8;
  bb.appendBits(0, Math.min(4, dataCapacityBits - bb.bits.length));      // terminator
  bb.appendBits(0, (8 - bb.bits.length % 8) % 8);                        // byte align
  for (var padByte = 0xEC; bb.bits.length < dataCapacityBits; padByte ^= 0xEC ^ 0x11)
    bb.appendBits(padByte, 8);                                           // pad bytes

  var dataCodewords = [];
  for (i = 0; i < bb.bits.length; i += 8) {
    var b = 0;
    for (var j = 0; j < 8; j++) b = (b << 1) | bb.bits[i + j];
    dataCodewords.push(b);
  }
  return new QrCode(version, ecl, dataCodewords, -1);
}

/* --- SVG renderer: one path, quiet zone border, viewBox-scaled --- */
function toSvgString(qr, border, lightColor, darkColor){
  if (border < 0) border = 4;
  var parts = [];
  for (var y = 0; y < qr.size; y++)
    for (var x = 0; x < qr.size; x++)
      if (qr.getModule(x, y))
        parts.push("M" + (x + border) + "," + (y + border) + "h1v1h-1z");
  var dim = qr.size + border * 2;
  return '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="0 0 ' + dim + ' ' + dim +
    '" stroke="none" shape-rendering="crispEdges">' +
    '<rect width="100%" height="100%" fill="' + (lightColor || "#FFFFFF") + '"/>' +
    '<path d="' + parts.join(" ") + '" fill="' + (darkColor || "#000000") + '"/></svg>';
}

/* ===================== Curve25519 (tweetnacl-derived, public domain) ===================== */

function gf(init){
  var r = new Float64Array(16);
  if (init) for (var i = 0; i < init.length; i++) r[i] = init[i];
  return r;
}
var _121665 = gf([0xdb41, 1]);
var _9 = new Uint8Array(32); _9[0] = 9;

function car25519(o){
  var c = 1;
  for (var i = 0; i < 16; i++) {
    var v = o[i] + c + 65535;
    c = Math.floor(v / 65536);
    o[i] = v - c * 65536;
  }
  o[0] += c - 1 + 37 * (c - 1);
}
function sel25519(p, q, b){
  var t, c = ~(b - 1);
  for (var i = 0; i < 16; i++) {
    t = c & (p[i] ^ q[i]);
    p[i] ^= t;
    q[i] ^= t;
  }
}
function pack25519(o, n){
  var i, j, b;
  var m = gf(), t = gf();
  for (i = 0; i < 16; i++) t[i] = n[i];
  car25519(t); car25519(t); car25519(t);
  for (j = 0; j < 2; j++) {
    m[0] = t[0] - 0xffed;
    for (i = 1; i < 15; i++) {
      m[i] = t[i] - 0xffff - ((m[i - 1] >> 16) & 1);
      m[i - 1] &= 0xffff;
    }
    m[15] = t[15] - 0x7fff - ((m[14] >> 16) & 1);
    b = (m[15] >> 16) & 1;
    m[14] &= 0xffff;
    sel25519(t, m, 1 - b);
  }
  for (i = 0; i < 16; i++) {
    o[2 * i] = t[i] & 0xff;
    o[2 * i + 1] = t[i] >> 8;
  }
}
function unpack25519(o, n){
  for (var i = 0; i < 16; i++) o[i] = n[2 * i] + (n[2 * i + 1] << 8);
  o[15] &= 0x7fff;
}
function A(o, a, b){ for (var i = 0; i < 16; i++) o[i] = a[i] + b[i]; }
function Z(o, a, b){ for (var i = 0; i < 16; i++) o[i] = a[i] - b[i]; }
function M(o, a, b){
  var v, c,
    t0 = 0, t1 = 0, t2 = 0, t3 = 0, t4 = 0, t5 = 0, t6 = 0, t7 = 0,
    t8 = 0, t9 = 0, t10 = 0, t11 = 0, t12 = 0, t13 = 0, t14 = 0, t15 = 0,
    t16 = 0, t17 = 0, t18 = 0, t19 = 0, t20 = 0, t21 = 0, t22 = 0, t23 = 0,
    t24 = 0, t25 = 0, t26 = 0, t27 = 0, t28 = 0, t29 = 0, t30 = 0,
    b0 = b[0], b1 = b[1], b2 = b[2], b3 = b[3], b4 = b[4], b5 = b[5],
    b6 = b[6], b7 = b[7], b8 = b[8], b9 = b[9], b10 = b[10], b11 = b[11],
    b12 = b[12], b13 = b[13], b14 = b[14], b15 = b[15];
  v = a[0];
  t0 += v * b0; t1 += v * b1; t2 += v * b2; t3 += v * b3; t4 += v * b4; t5 += v * b5;
  t6 += v * b6; t7 += v * b7; t8 += v * b8; t9 += v * b9; t10 += v * b10; t11 += v * b11;
  t12 += v * b12; t13 += v * b13; t14 += v * b14; t15 += v * b15;
  v = a[1];
  t1 += v * b0; t2 += v * b1; t3 += v * b2; t4 += v * b3; t5 += v * b4; t6 += v * b5;
  t7 += v * b6; t8 += v * b7; t9 += v * b8; t10 += v * b9; t11 += v * b10; t12 += v * b11;
  t13 += v * b12; t14 += v * b13; t15 += v * b14; t16 += v * b15;
  v = a[2];
  t2 += v * b0; t3 += v * b1; t4 += v * b2; t5 += v * b3; t6 += v * b4; t7 += v * b5;
  t8 += v * b6; t9 += v * b7; t10 += v * b8; t11 += v * b9; t12 += v * b10; t13 += v * b11;
  t14 += v * b12; t15 += v * b13; t16 += v * b14; t17 += v * b15;
  v = a[3];
  t3 += v * b0; t4 += v * b1; t5 += v * b2; t6 += v * b3; t7 += v * b4; t8 += v * b5;
  t9 += v * b6; t10 += v * b7; t11 += v * b8; t12 += v * b9; t13 += v * b10; t14 += v * b11;
  t15 += v * b12; t16 += v * b13; t17 += v * b14; t18 += v * b15;
  v = a[4];
  t4 += v * b0; t5 += v * b1; t6 += v * b2; t7 += v * b3; t8 += v * b4; t9 += v * b5;
  t10 += v * b6; t11 += v * b7; t12 += v * b8; t13 += v * b9; t14 += v * b10; t15 += v * b11;
  t16 += v * b12; t17 += v * b13; t18 += v * b14; t19 += v * b15;
  v = a[5];
  t5 += v * b0; t6 += v * b1; t7 += v * b2; t8 += v * b3; t9 += v * b4; t10 += v * b5;
  t11 += v * b6; t12 += v * b7; t13 += v * b8; t14 += v * b9; t15 += v * b10; t16 += v * b11;
  t17 += v * b12; t18 += v * b13; t19 += v * b14; t20 += v * b15;
  v = a[6];
  t6 += v * b0; t7 += v * b1; t8 += v * b2; t9 += v * b3; t10 += v * b4; t11 += v * b5;
  t12 += v * b6; t13 += v * b7; t14 += v * b8; t15 += v * b9; t16 += v * b10; t17 += v * b11;
  t18 += v * b12; t19 += v * b13; t20 += v * b14; t21 += v * b15;
  v = a[7];
  t7 += v * b0; t8 += v * b1; t9 += v * b2; t10 += v * b3; t11 += v * b4; t12 += v * b5;
  t13 += v * b6; t14 += v * b7; t15 += v * b8; t16 += v * b9; t17 += v * b10; t18 += v * b11;
  t19 += v * b12; t20 += v * b13; t21 += v * b14; t22 += v * b15;
  v = a[8];
  t8 += v * b0; t9 += v * b1; t10 += v * b2; t11 += v * b3; t12 += v * b4; t13 += v * b5;
  t14 += v * b6; t15 += v * b7; t16 += v * b8; t17 += v * b9; t18 += v * b10; t19 += v * b11;
  t20 += v * b12; t21 += v * b13; t22 += v * b14; t23 += v * b15;
  v = a[9];
  t9 += v * b0; t10 += v * b1; t11 += v * b2; t12 += v * b3; t13 += v * b4; t14 += v * b5;
  t15 += v * b6; t16 += v * b7; t17 += v * b8; t18 += v * b9; t19 += v * b10; t20 += v * b11;
  t21 += v * b12; t22 += v * b13; t23 += v * b14; t24 += v * b15;
  v = a[10];
  t10 += v * b0; t11 += v * b1; t12 += v * b2; t13 += v * b3; t14 += v * b4; t15 += v * b5;
  t16 += v * b6; t17 += v * b7; t18 += v * b8; t19 += v * b9; t20 += v * b10; t21 += v * b11;
  t22 += v * b12; t23 += v * b13; t24 += v * b14; t25 += v * b15;
  v = a[11];
  t11 += v * b0; t12 += v * b1; t13 += v * b2; t14 += v * b3; t15 += v * b4; t16 += v * b5;
  t17 += v * b6; t18 += v * b7; t19 += v * b8; t20 += v * b9; t21 += v * b10; t22 += v * b11;
  t23 += v * b12; t24 += v * b13; t25 += v * b14; t26 += v * b15;
  v = a[12];
  t12 += v * b0; t13 += v * b1; t14 += v * b2; t15 += v * b3; t16 += v * b4; t17 += v * b5;
  t18 += v * b6; t19 += v * b7; t20 += v * b8; t21 += v * b9; t22 += v * b10; t23 += v * b11;
  t24 += v * b12; t25 += v * b13; t26 += v * b14; t27 += v * b15;
  v = a[13];
  t13 += v * b0; t14 += v * b1; t15 += v * b2; t16 += v * b3; t17 += v * b4; t18 += v * b5;
  t19 += v * b6; t20 += v * b7; t21 += v * b8; t22 += v * b9; t23 += v * b10; t24 += v * b11;
  t25 += v * b12; t26 += v * b13; t27 += v * b14; t28 += v * b15;
  v = a[14];
  t14 += v * b0; t15 += v * b1; t16 += v * b2; t17 += v * b3; t18 += v * b4; t19 += v * b5;
  t20 += v * b6; t21 += v * b7; t22 += v * b8; t23 += v * b9; t24 += v * b10; t25 += v * b11;
  t26 += v * b12; t27 += v * b13; t28 += v * b14; t29 += v * b15;
  v = a[15];
  t15 += v * b0; t16 += v * b1; t17 += v * b2; t18 += v * b3; t19 += v * b4; t20 += v * b5;
  t21 += v * b6; t22 += v * b7; t23 += v * b8; t24 += v * b9; t25 += v * b10; t26 += v * b11;
  t27 += v * b12; t28 += v * b13; t29 += v * b14; t30 += v * b15;
  t0 += 38 * t16; t1 += 38 * t17; t2 += 38 * t18; t3 += 38 * t19; t4 += 38 * t20;
  t5 += 38 * t21; t6 += 38 * t22; t7 += 38 * t23; t8 += 38 * t24; t9 += 38 * t25;
  t10 += 38 * t26; t11 += 38 * t27; t12 += 38 * t28; t13 += 38 * t29; t14 += 38 * t30;
  c = 1;
  v = t0 + c + 65535; c = Math.floor(v / 65536); t0 = v - c * 65536;
  v = t1 + c + 65535; c = Math.floor(v / 65536); t1 = v - c * 65536;
  v = t2 + c + 65535; c = Math.floor(v / 65536); t2 = v - c * 65536;
  v = t3 + c + 65535; c = Math.floor(v / 65536); t3 = v - c * 65536;
  v = t4 + c + 65535; c = Math.floor(v / 65536); t4 = v - c * 65536;
  v = t5 + c + 65535; c = Math.floor(v / 65536); t5 = v - c * 65536;
  v = t6 + c + 65535; c = Math.floor(v / 65536); t6 = v - c * 65536;
  v = t7 + c + 65535; c = Math.floor(v / 65536); t7 = v - c * 65536;
  v = t8 + c + 65535; c = Math.floor(v / 65536); t8 = v - c * 65536;
  v = t9 + c + 65535; c = Math.floor(v / 65536); t9 = v - c * 65536;
  v = t10 + c + 65535; c = Math.floor(v / 65536); t10 = v - c * 65536;
  v = t11 + c + 65535; c = Math.floor(v / 65536); t11 = v - c * 65536;
  v = t12 + c + 65535; c = Math.floor(v / 65536); t12 = v - c * 65536;
  v = t13 + c + 65535; c = Math.floor(v / 65536); t13 = v - c * 65536;
  v = t14 + c + 65535; c = Math.floor(v / 65536); t14 = v - c * 65536;
  v = t15 + c + 65535; c = Math.floor(v / 65536); t15 = v - c * 65536;
  t0 += c - 1 + 37 * (c - 1);
  c = 1;
  v = t0 + c + 65535; c = Math.floor(v / 65536); t0 = v - c * 65536;
  v = t1 + c + 65535; c = Math.floor(v / 65536); t1 = v - c * 65536;
  v = t2 + c + 65535; c = Math.floor(v / 65536); t2 = v - c * 65536;
  v = t3 + c + 65535; c = Math.floor(v / 65536); t3 = v - c * 65536;
  v = t4 + c + 65535; c = Math.floor(v / 65536); t4 = v - c * 65536;
  v = t5 + c + 65535; c = Math.floor(v / 65536); t5 = v - c * 65536;
  v = t6 + c + 65535; c = Math.floor(v / 65536); t6 = v - c * 65536;
  v = t7 + c + 65535; c = Math.floor(v / 65536); t7 = v - c * 65536;
  v = t8 + c + 65535; c = Math.floor(v / 65536); t8 = v - c * 65536;
  v = t9 + c + 65535; c = Math.floor(v / 65536); t9 = v - c * 65536;
  v = t10 + c + 65535; c = Math.floor(v / 65536); t10 = v - c * 65536;
  v = t11 + c + 65535; c = Math.floor(v / 65536); t11 = v - c * 65536;
  v = t12 + c + 65535; c = Math.floor(v / 65536); t12 = v - c * 65536;
  v = t13 + c + 65535; c = Math.floor(v / 65536); t13 = v - c * 65536;
  v = t14 + c + 65535; c = Math.floor(v / 65536); t14 = v - c * 65536;
  v = t15 + c + 65535; c = Math.floor(v / 65536); t15 = v - c * 65536;
  t0 += c - 1 + 37 * (c - 1);
  o[0] = t0; o[1] = t1; o[2] = t2; o[3] = t3; o[4] = t4; o[5] = t5; o[6] = t6; o[7] = t7;
  o[8] = t8; o[9] = t9; o[10] = t10; o[11] = t11; o[12] = t12; o[13] = t13; o[14] = t14; o[15] = t15;
}
function S(o, a){ M(o, a, a); }
function inv25519(o, i){
  var c = gf(), a;
  for (a = 0; a < 16; a++) c[a] = i[a];
  for (a = 253; a >= 0; a--) {
    S(c, c);
    if (a !== 2 && a !== 4) M(c, c, i);
  }
  for (a = 0; a < 16; a++) o[a] = c[a];
}
function crypto_scalarmult(q, n, p){
  var z = new Uint8Array(32);
  var x = new Float64Array(80), r, i;
  var a = gf(), b = gf(), c = gf(), d = gf(), e = gf(), f = gf();
  for (i = 0; i < 31; i++) z[i] = n[i];
  z[31] = (n[31] & 127) | 64;
  z[0] &= 248;
  unpack25519(x, p);
  for (i = 0; i < 16; i++) { b[i] = x[i]; d[i] = a[i] = c[i] = 0; }
  a[0] = d[0] = 1;
  for (i = 254; i >= 0; --i) {
    r = (z[i >>> 3] >>> (i & 7)) & 1;
    sel25519(a, b, r);
    sel25519(c, d, r);
    A(e, a, c); Z(a, a, c); A(c, b, d); Z(b, b, d);
    S(d, e); S(f, a); M(a, c, a); M(c, b, e);
    A(e, a, c); Z(a, a, c); S(b, a); Z(c, d, f);
    M(a, c, _121665); A(a, a, d); M(c, c, a); M(a, d, f); M(d, b, x); S(b, e);
    sel25519(a, b, r);
    sel25519(c, d, r);
  }
  for (i = 0; i < 16; i++) {
    x[i + 16] = a[i]; x[i + 32] = c[i]; x[i + 48] = b[i]; x[i + 64] = d[i];
  }
  var x32 = x.subarray(32), x16 = x.subarray(16);
  inv25519(x32, x32);
  M(x16, x16, x32);
  pack25519(q, x16);
  return 0;
}
function crypto_scalarmult_base(q, n){ return crypto_scalarmult(q, n, _9); }

/* --- base64 <-> bytes (no atob dependence on odd charsets) --- */
var B64C = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
function bytesToB64(bytes){
  var out = "", i;
  for (i = 0; i + 2 < bytes.length; i += 3) {
    var n = (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
    out += B64C[(n >>> 18) & 63] + B64C[(n >>> 12) & 63] + B64C[(n >>> 6) & 63] + B64C[n & 63];
  }
  var rem = bytes.length - i;
  if (rem === 1) {
    out += B64C[(bytes[i] >>> 2) & 63] + B64C[(bytes[i] << 4) & 63] + "==";
  } else if (rem === 2) {
    var m = (bytes[i] << 8) | bytes[i + 1];
    out += B64C[(m >>> 10) & 63] + B64C[(m >>> 4) & 63] + B64C[(m << 2) & 63] + "=";
  }
  return out;
}
function b64ToBytes(s){
  s = (s || "").replace(/[^A-Za-z0-9+/]/g, "");
  var out = [], i, buf = 0, bits = 0;
  for (i = 0; i < s.length; i++) {
    buf = (buf << 6) | B64C.indexOf(s.charAt(i));
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      out.push((buf >>> bits) & 0xFF);
    }
  }
  return out;
}

function randomBytes32(){
  var b = new Uint8Array(32);
  var cr = (typeof crypto !== "undefined" && crypto.getRandomValues) ? crypto :
           (typeof window !== "undefined" && window.msCrypto) ? window.msCrypto : null;
  if (!cr) throw "No secure random source (crypto.getRandomValues) in this browser";
  cr.getRandomValues(b);
  return b;
}

/* ===================== exports ===================== */
var root = (typeof window !== "undefined") ? window :
           (typeof globalThis !== "undefined") ? globalThis : {};

root.AWGQR = {
  Ecc: ECC,
  encodeText: encodeText,       // (text, ecl?) -> QrCode {size, getModule(x,y), version, mask}
  toSvgString: toSvgString      // (qr, border, light?, dark?) -> "<svg …>"
};

root.AWGKeys = {
  genPrivkey: function(){
    var b = randomBytes32();
    b[0] &= 248; b[31] = (b[31] & 127) | 64;   // WG clamping — stored keys are pre-clamped
    return bytesToB64(b);
  },
  pubFromPriv: function(privB64){
    var priv = b64ToBytes(privB64);
    if (priv.length !== 32) return "";
    var q = new Uint8Array(32);
    crypto_scalarmult_base(q, new Uint8Array(priv));
    return bytesToB64(q);
  },
  genPsk: function(){
    return bytesToB64(randomBytes32());
  },
  isValidKey: function(k){
    return /^[A-Za-z0-9+/]{42}[AEIMQUYcgkosw048]=$/.test(k || "");
  }
};

/* Node.js test hook (unused in the browser) */
if (typeof module !== "undefined" && module.exports) {
  module.exports = { AWGQR: root.AWGQR, AWGKeys: root.AWGKeys,
    _internals: { getNumRawDataModules: getNumRawDataModules, getNumDataCodewords: getNumDataCodewords,
                  ECC: ECC, ECC_CODEWORDS_PER_BLOCK: ECC_CODEWORDS_PER_BLOCK,
                  NUM_ERROR_CORRECTION_BLOCKS: NUM_ERROR_CORRECTION_BLOCKS,
                  rsComputeDivisor: rsComputeDivisor, rsComputeRemainder: rsComputeRemainder,
                  crypto_scalarmult_base: crypto_scalarmult_base,
                  bytesToB64: bytesToB64, b64ToBytes: b64ToBytes } };
}
})();

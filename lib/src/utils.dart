library utils;

import 'dart:math' as Math;
import 'dart:html';

import "package:dart2_constant/convert.dart" as convert;

import "../sockjs_client.dart" as SockJS;

const random_string_chars = 'abcdefghijklmnopqrstuvwxyz0123456789_';
String random_string(length, [max]) {
    if (max == null) max = random_string_chars.length;
    var i, ret = [], rnd = new Math.Random(), r;
    for(i=0; i < length; i++) {
        r = rnd.nextInt(max);
        ret.add( random_string_chars.substring(r, r+1) );
    }
    return ret.join('');
}

int random_number(max) => new Math.Random().nextInt(max);

String random_number_string(max) {
    var t = "${max - 1}".length;
    var l = new List();
    for (int i = 0; i < t+1; i++) {
      l.add('0');
    }
    var p = l.join('');
    var s = "$p${random_number(max)}";
    return s.substring(s.length - t);
}

bool flatUrl(String url) => url.indexOf('?') == -1 && url.indexOf('#') == -1;

String amendUrl(String url) {
    var dl = window.location;

    if (url == null) {
        throw 'Wrong url for SockJS';
    }
    if (!flatUrl(url)) {
        throw 'Only basic urls are supported in SockJS';
    }

    //  '//abc' --> 'http://abc'
    if (url.indexOf('//') == 0) {
        url = "${dl.protocol}$url";
    }
    // '/abc' --> 'http://localhost:80/abc'
    if (url.indexOf('/') == 0) {
        url = "${dl.protocol}//${dl.host}$url";
    }
    // strip trailing slashes
    url = url.replaceAll(new RegExp(r'/[/]+$/'),'');
    return url;
}

closeFrame(code, reason) => 'c${convert.json.encode([code, reason])}';

bool userSetCode(int code) => code == 1000 || (code >= 3000 && code <= 4999);

// See: http://www.erg.abdn.ac.uk/~gerrit/dccp/notes/ccid2/rto_estimator/
// and RFC 2988.
num countRTO(num rtt) {
    var rto;
    if (rtt > 100) {
        rto = 3 * rtt; // rto > 300msec
    } else {
        rto = rtt + 200; // 200msec < rto <= 300msec
    }
    return rto;
}

bool isSameOriginUrl(String url_a, [String url_b]) {
    // location.origin would do, but it's not always available.
    if (url_b == null) url_b = window.location.toString();

    return ( url_a.split('/').getRange(0,3).join('/')
              == url_b.split('/').getRange(0,3).join('/'));
}

String quote(String string) => convert.json.encode(string);

const _all_protocols = const [
                       'websocket',
                      'xdr-streaming',
                      'xhr-streaming',
                      'iframe-eventsource',
                      'iframe-htmlfile',
                      'xdr-polling',
                      'xhr-polling',
                      'iframe-xhr-polling',
                      'jsonp-polling'];

Map<String, bool> probeProtocols() {
    final probed = <String, bool>{};
    for (final protocol in _all_protocols) {
        // User can have a typo in protocol name.
        probed[protocol] = SockJS.PROTOCOLS.containsKey(protocol) && SockJS.PROTOCOLS[protocol].enabled;
    }
    return probed;
}

List<String> detectProtocols(Map<String, bool> probed, [List<String> protocols_whitelist, SockJS.Info info] ) {
    final pe = <String, bool>{};
    final protocols = <String>[];
    if (protocols_whitelist == null) {
      protocols_whitelist = _all_protocols;
    }
    protocols_whitelist.forEach((protocol) => pe[protocol] = probed[protocol]);

    void maybe_push(List<String> protos) {
        var proto = protos.removeAt(0);
        if (pe[proto] != null) {
            protocols.add(proto);
        } else {
            if (!protos.isEmpty) {
                maybe_push(protos);
            }
        }
    };

    // 1. Websocket
    if (info.websocket) {
        maybe_push(['websocket']);
    }

    // 2. Streaming
    if (pe['xhr-streaming'] != null && !info.nullOrigin) {
        protocols.add('xhr-streaming');
    } else {
        if (pe['xdr-streaming'] != null && !info.cookieNeeded && !info.nullOrigin) {
            protocols.add('xdr-streaming');
        } else {
            maybe_push(['iframe-eventsource',
                        'iframe-htmlfile']);
        }
    }

    // 3. Polling
    if (pe['xhr-polling'] != null && !info.nullOrigin) {
        protocols.add('xhr-polling');
    } else {
        if (pe['xdr-polling'] != null && !info.cookieNeeded && !info.nullOrigin) {
            protocols.add('xdr-polling');
        } else {
            maybe_push(['iframe-xhr-polling',
                        'jsonp-polling']);
        }
    }
    return protocols;
}

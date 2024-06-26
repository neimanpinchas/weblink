package weblink._internal;

import haxe.io.Bytes;
import js.node.Buffer;
#if hl
import hl.uv.Stream;
#else
// typedef Stream = js.node.net.Socket;

abstract Stream(js.node.net.Socket) {
	// public extern function write(b:Bytes):Void;
	// public extern function close(?callb:() -> Void):Void;
	public function new(s:js.node.net.Socket) {
		this = s;
	}

	public function readStart(callb:(data:Bytes) -> Void) {
		this.on("data", function(d:Buffer) {
			callb(d.hxToBytes());
		});
	}

	public function close() {
		this.end();
	}

	// TODO we really want a js buffer
	public function write(b:Bytes) {
		this.write(b.toString());
	}
}
#end

private typedef Basic = Stream

abstract Socket(Basic) {
	inline public function new(i:Basic) {
		this = i;
	}

	public inline function writeString(string:String) {
		this.write(Bytes.ofString(string, UTF8));
	}

	public inline function writeBytes(bytes:Bytes) {
		this.write(bytes);
	}

	public function close() {
		this.close();
	}
}

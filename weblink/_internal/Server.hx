package weblink._internal;
import haxe.MainLoop;
import haxe.io.Bytes;
import haxe.http.HttpMethod;
import sys.net.Host;
import weblink._internal.Socket;

class Server extends SocketServer
{
    var sockets:Array<Socket>;
    var parent:Weblink;
    var running:Bool = true;
    #if (hl && !nolibuv) var loop:hl.uv.Loop; #end
    public function new(port:Int,parent:Weblink)
    {
        sockets = [];
        #if (hl && !nolibuv)
        loop = hl.uv.Loop.getDefault();
        super(loop);
        #else
        super();
        #end
        bind(new Host("0.0.0.0"),port);
        #if (hl && !nolibuv)
        noDelay(true);
        listen(100,function()
        {
            var stream = accept();
            var socket:Socket = cast stream;
            stream.readStart(function(data:Bytes)
            {
                if (data == null)
                {
                    sockets.remove(socket);
                    stream.close();
                    return;
                }
                var lines = data.toString().split("\r\n");
                //go through lines
                @:privateAccess var request = new Request(lines);
                @:privateAccess var response = request.response(this,socket);
                @:privateAccess parent.func(request,response);
            });
            sockets.push(socket);
        });
        #else
        listen(100); //queue up 100 connection sockets
        sys.thread.Thread.create(function()
        {
            while (running) getAccept();
        });
        #end
        this.parent = parent;
    }
    #if (!hl || nolibuv)
    private inline function getAccept()
    {
        try {
            var socket:Socket = cast accept();
            socket.set();
            sockets.push(socket);
        }catch(e:Dynamic)
        {
            if (!running) return;
            trace("e " + e);
        }
    }
    #end
    public function update()
    {
        #if (!hl || nolibuv)
        while (running)
        {
            @:privateAccess MainLoop.tick();
            #if !(target.threaded)
            getAccept();
            #end
            for (socket in sockets)
            {
                //existing connections run through
                var lines:Array<String> = [];
                while (true)
                {
                    try {
                        var line = socket.readLine();
                        lines.push(line);
                    }catch(e:Dynamic)
                    {
                        if (e != haxe.io.Error.Blocked)
                        {
                            trace("error " + e);
                            socket.close();
                            sockets.remove(socket);
                        }
                        break;
                    }
                }
                if (lines.length > 0)
                {
                    //go through lines
                    @:privateAccess var request = new Request(lines);
                    @:privateAccess var response = request.response(this,socket);
                    @:privateAccess parent.func(request,response);
                }
            }
            Sys.sleep(1/15);
        }
        #else
        while (running)
        {
            @:privateAccess MainLoop.tick(); //for timers
            loop.run(NoWait);
        }
        #end
    }
    override function close(#if (hl && !nolibuv) ?callb:() -> Void #end) 
    {
        //remove sockets array as well
        for (socket in sockets)
        {
            socket.close();
        }
        sockets = [];
        running = false;
        #if (hl && !nolibuv)
        loop.stop();
        #end
        super.close();
    }
}
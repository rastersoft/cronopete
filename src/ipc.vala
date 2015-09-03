/*
 Copyright 2011-2015 (C) Raster Software Vigo (Sergio Costas)

 This file is part of Cronopete

 Cronopete is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 3 of the License, or
 (at your option) any later version.

 Cronopete is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>. */
 
using GLib;
using Posix;
using Gee;

public class pipe_ipc:GLib.Object {

	private int[] fd;
	private IOChannel io_read;
    private IOChannel io_write;

	public signal void received_data(string msg,size_t len);

	public pipe_ipc() {

        this.fd = new int[2];
		fd[0] = -1;
		fd[1] = -1;
		this.init_pipes();
	}
	
	private void init_pipes() {

        int ret;

		if (fd[0] != -1) {
			Posix.close(fd[0]);
		}
		if (fd[1] != -1) {
			Posix.close(fd[1]);
		}

        // setup a pipe
        ret = Posix.pipe(this.fd);
        if(ret == -1) {
            print("Creating pipe failed: %s\n", Posix.strerror(Posix.errno));
        } else {
            // setup iochannels
            this.io_read  = new IOChannel.unix_new(fd[0]);
            this.io_write = new IOChannel.unix_new(fd[1]);

            if((this.io_read == null) || (this.io_write == null)) {
                print("Cannot create new IOChannel!\n");
            } else {
	            // The watch calls the gio_in function, if there data is available for
	            // reading without locking
	            if(!(this.io_read.add_watch(IOCondition.IN | IOCondition.HUP, this.receive_data) != 0)) {
	                print("Cannot add watch on IOChannel!\n");
    	        }
    	    }
        }
    }

	private bool receive_data(IOChannel gio, IOCondition condition) {

        IOStatus ret;
        string msg;
        size_t len;

        if ((condition & IOCondition.HUP) == IOCondition.HUP) {
            print("Read end of pipe died!\n");
            this.init_pipes();
            return false;
        }

        try {
            ret = gio.read_line(out msg, out len, null);
        }
        catch(IOChannelError e) {
            print("Error reading: %s\n".printf(e.message));
            return true;
        }
        catch(ConvertError e) {
            print("Error reading: %s\n".printf(e.message));
            return true;
        }
		
		this.received_data(msg.substring(0,(long)(len-1)).replace("\r","\n"),len);
        return true;
    }

	public void send_data(string msg) {
		size_t len;
        this.io_write.write_chars((char[])((msg.replace("\n","\r"))+"\n"),out len);
        this.io_write.flush();
	}
}

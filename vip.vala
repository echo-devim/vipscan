using GLib;

public class ScanResult {
	public string ip;
	public int port;

	public ScanResult(string ip, int port) {
		this.ip = ip;
		this.port = port;
	}
}

public class ScanWindow : Gtk.Window {
	private Cairo.Context ctx = null;
	private Gtk.DrawingArea drawing_area;
	private AsyncQueue<ScanResult> results;
	private Mutex result_mutex;
	private bool scan_finished;

	public ScanWindow() {
		this.results = new AsyncQueue<ScanResult>();
	}

	private void setupgui() {
		this.set_title ("VIP Scan");
		this.set_default_size (800, 500);
		var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 5);
		drawing_area = new Gtk.DrawingArea();
		drawing_area.draw.connect (on_draw);
		box.pack_start(drawing_area);
		this.add(box);
	}

	public bool on_draw(Gtk.Widget da, Cairo.Context cr) {
		this.ctx = cr;
		ctx.set_source_rgba (1, 1, 1, 1);
		ctx.rectangle (0, 0, this.default_width, this.default_height);
		ctx.fill ();
		ctx.select_font_face ("DroidSans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
		ctx.set_font_size (14);
		long rowpx = 0;
		//The following second queue is used to make a copy of the original queue
		AsyncQueue<ScanResult> result_queue = new AsyncQueue<ScanResult>();
		while (this.results.length() > 0) {
			long offset = rowpx / (this.default_height - 30);
			ctx.move_to (offset*100 + 10, (rowpx % (this.default_height - 30)) + 20);
			//We must pop the element in order to get a reference to it
			ScanResult sr = this.results.pop();
			float color_index = (float)sr.port/1024;
			if (color_index > 1)
				color_index = 1;
			ctx.set_source_rgba (0,1-color_index,0, 1);
			//Don't forget the popped element, keep it in the second queue 
			result_queue.push(sr);
			ctx.show_text(sr.ip + "  " + sr.port.to_string());
			rowpx += 20;
		}
		//After we rendered the results, we restore the original queue
		this.results = result_queue;
		//Render the status bar
		ctx.set_source_rgba (0.6,0.6,0.6, 1);
		ctx.rectangle (0, this.default_height - 20, this.default_width, 20);
		ctx.fill ();
		ctx.set_source_rgba (0.2,0.2,0.2, 1);
		ctx.move_to (10, this.default_height - 5);
		if (this.scan_finished) {
			ctx.show_text("Done!");
		} else {
			ctx.show_text("Scanning.. please wait");
		}

		return true;
	}

	public void on_done() {
		stdout.printf("Done\n");
		this.scan_finished = true;
		this.drawing_area.queue_draw();
	}

	public bool setup(string ip_start, string ip_end) {
		setupgui();
		if ((ip_start == "") || (ip_end == ""))
			return false;
		scan_finished = false;
		var se = new ScanEngine();
		se.result.connect(result_callback);
		se.done.connect(on_done);
		se.scan(ip_start, ip_end);

		return true;
	}

	public void result_callback(string ip, int openport) {
		//This method is called from multiple threads
		result_mutex.lock();
		this.results.push(new ScanResult(ip, openport));
		stdout.printf("%s open port %d\n", ip, openport);
		result_mutex.unlock();
		
	}
}

public class ConfigWindow : Gtk.Window {
	public string ip_start;
	public string ip_end;

	public void setup(ScanWindow sw) {
		this.ip_start = "";
		this.ip_end = "";
		var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
		var row1 = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
		var row2 = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
		var lblStart = new Gtk.Label ("IP Start Range:");
		lblStart.set_halign(Gtk.Align.START);
		var txtIPStart = new Gtk.Entry();
		txtIPStart.set_text("127.0.0.1");
		var lblEnd = new Gtk.Label ("IP End Range:");
		lblEnd.set_halign(Gtk.Align.START);
		var txtIPEnd = new Gtk.Entry();
		txtIPEnd.set_text("127.0.0.1");
		var btnScan = new Gtk.Button.with_label("Scan");
		btnScan.clicked.connect ( () => {
			this.ip_start = txtIPStart.get_text();
			this.ip_end = txtIPEnd.get_text();
			this.close();
			if (sw.setup(ip_start, ip_end))
				sw.show_all();
			else
				Process.exit(1);
				
		});
		row1.pack_start(lblStart);
		row1.pack_start(txtIPStart);
		row2.pack_start(lblEnd);
		row2.pack_start(txtIPEnd);
		box.pack_start(row1);
		box.pack_start(row2);
		box.pack_start(btnScan);
		this.add (box);
		this.set_title ("VIP Scan Configuration");
		this.set_default_size (300, 200);
	}
}

public class VIP : Gtk.Application {
	protected override void activate () {
		var sw = new ScanWindow();
		var cw = new ConfigWindow();
		this.add_window(cw);
		cw.setup(sw);
		cw.show_all();
		this.add_window(sw);
	}
}

public int main (string[] args) {
	return new VIP ().run (args);
}

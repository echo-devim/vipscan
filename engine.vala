public class ScanEngine {
    private int threads;
    private Mutex mutexth;

    public signal void done();
    public signal void result (string ip, int openport);

    public ScanEngine() {
        this.threads = 0;
    }

    // This class supports only IPv4 addresses
    public string[] getIPAddressesFromRange(string ip_start,string ip_end) {
        // This method is just a draft implementation, it expands only 255.255.0.0 addresses
        string[] result = {};
        string[] s_octects = ip_start.split(".");
        string[] e_octects = ip_end.split(".");
        for (int i = 0; i < 4; i++) {
            int startrange = int.parse(s_octects[i]);
            int endrange = int.parse(e_octects[i]);
            if (endrange > startrange) {
                switch(i) {
                    case 0:
                        //TODO
                    case 1:
                        //TODO
                    case 2:
                        int s = int.parse(s_octects[3]);
                        int j = startrange;
                        int le = int.parse(e_octects[3]);
                        while (j <= endrange) {
                            if ((j == endrange) && (s > le)) {
                                break;
                            }
                            result += s_octects[0] + "." + s_octects[1] + "." + j.to_string() + "." + s.to_string();
                            s++;
                            if (s > 255) {
                                s = 0;
                                j++;
                            }
                        }
                        break;
                    case 3:
                        for (int s = startrange; s <= endrange; s++) {
                            result += s_octects[0] + "." + s_octects[1] + "." + s_octects[2] + "." + s.to_string();
                        }
                        break;
                }
            }
        }
        if (result.length == 0) {
            result += ip_start;
        }
        return result;
    }

    public void scan(string ip_start, string ip_end) {
        stdout.printf("ip_start = %s, ip_end = %s\n", ip_start, ip_end);
        string[] ip_addresses = getIPAddressesFromRange(ip_start, ip_end);
        foreach (string ip_address in ip_addresses) {
            mutexth.lock();
            threads++;
            mutexth.unlock();
            Thread<void*> thread = new Thread<void*> ("Port Scan Thread", () => {
                portScan(ip_address);
                return null;
            });
        }
    }

    public void on_done() {
        mutexth.lock();
        threads--;
        //When all the threads we started to scan each ip have finished, we emit the done() signal
        if (threads <= 0) {
            threads = 0;
            this.done();
        }
        mutexth.unlock();
    }

    public void portScan(string ip) {
        var ps = new PortScanner(ip, this);
        ps.done.connect(on_done);
        ps.scan();
    }
}

class PortScanner {
    private string ip;
    private ScanEngine se;

    public signal void done();

    public PortScanner(string ip, ScanEngine se) {
        this.ip = ip;
        this.se = se;
    }

    public void scan() {
        int maxthreads = 16;
        try {
            ThreadPool<ScanWorker> tpool = new ThreadPool<ScanWorker>.with_owned_data ((thr) => {
                thr.run ();
            }, maxthreads, false);
            for (int tid = 0; tid < 16; tid++)
                tpool.add(new ScanWorker(tid, ip, se));
            
            while (true) {
                uint running_threads = tpool.get_num_threads();
                if ((running_threads == 0) && (tpool.unprocessed() == 0)) {
                    this.done(); //emit signal
                    break;
                }
                Thread.usleep (1000000); //wait a second
            }
        } catch (ThreadError e) {
            print ("ThreadError: %s\n", e.message);
        }
    }

}

class ScanWorker {
    private int portstart;
    private int portend;
    private string ip;
    private ScanEngine se;

    public ScanWorker(int tid, string ip, ScanEngine se) {
        this.portstart = 4096*tid;
        this.portend = portstart + 4096;
        this.ip = ip;
        this.se = se;
    }

    public void run () {
        InetAddress address = new InetAddress.from_string(ip);
        for (int p = portstart; p <= portend; p++) {
            try {
                Socket socket = new Socket (SocketFamily.IPV4, SocketType.STREAM, SocketProtocol.TCP);
                socket.set_timeout(3000);
                assert (socket != null);
                InetSocketAddress inetaddress = new InetSocketAddress (address, (uint16)p);
                if (socket.connect(inetaddress)) {
                    se.result(ip, p);
                }
            } catch (Error e) {
            }
        }
    }
}
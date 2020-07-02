# VIP Scan
VIP Scan is an experimental port scanner written in Vala. I did it just as an exercise.
It has still several limitations and bugs.

It can scan up to 0.0.0.0/16 subnet. For each host is executed a different thread that performs a port scan. Each port scan is performed in parallel using 16 threads.
This means that with a large subnet VIP is going to use a large number of threads.

The gui is very poor and at an early stage. Actually, it uses Pango with Cairo to render the results.
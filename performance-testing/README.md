## Performance testing

### Overview
A load tester was implemented inside an Ubuntu v20.04LTS image. 
It is based on the h2load tool (which is part of the nghttp2 v1.41.0 project), 
with a QSC-enabled OpenSSL v1.1.1g which provides the TLS connectivity. 

The h2load tool provides information about the time required for TLS connection establishment, including TCP handshake. 

The goal of the load testing was to determine any latency penalty when establishing a TLSv1.3 
connection in comparison with the legacy X25519 curve. 

### Test procedure
For each test, 1000 requests were sent for warm-up, 
followed by sequential 10’000 HTTPS requests for measurements. 
Connections were closed after each request. 

These tests were first executed for the x25519 curve and then repeated for each curve/KEM under test. 
Finally, the entire measurement sequence was repeated 5 times to get some insight about variability. 
This approach allows to reach a measurement accuracy of only a few micro-seconds. 

The tests were executed in a production environment in the IBM Cloud (Frankfurt DC, using two "bx2.4x16" nodes in each cluster). Timings might vary for a user as they are dependent on network load from neighboring services and load on the cluster. 

To minimize any network latency drift effects, the test were executed from within the cluster by having a single pod issuing requests to the external network address of the cluster. 

### Test results
The table below summarizes the measurement results.

![Test_Results](../images/TestResults.jpg?raw=true)

### Discussion
As can be seen from the table above, using kyber512 results in 
slightly faster connection establishment when compared to the X25519 curve, 
and kyber1024 is less than 100us slower compared to the X25519 
curve - but at significantly higher security level! 

Using the hybrid p256-kyber512 
curve/KEM only adds ~150us to the connection establishment when compared to only using the 
legacy p256 curve. 

This must be put into relation to the ~2ms total connection establishment time 
for a p256 curve and hence a hybrid p256-kyber512 adds – even under best case 
scenario of super closely spaced network endpoints – less than 10% latency. 

For regular use cases where the HTTPS client is outside the cloud date-center 
and were network latency is measured in double digit milli-seconds, this ~150us 
latency penalty when using a hybrid curve becomes negligible.

(Note: KEM = key exchange mechanism)

A cURL client is implemented inside a Docker image. 

Great care was applied to have both the original libcurl as well as an QSC-enabled libcurl available in parallel. 

For that purpose, OpenSSL was built with QSC support from OQS, with the addition of `_oqs` suffix in the libraries, which are therefore named `libcrypto_oqs` and `libssl_oqs`. 

For cURL, the `versioned_symbols_flavour="OPENSSL_QSC_` was used in the `configure` file to distinguish library symbols from the original library. If you want to use the original cURL and the QSC-enabled cURL libraries in the same application, you have to build the code using cURL in two distinct libraries, each with unique symbol names, and then link those libs to your application. 

We also added two patches for OpenSSL, such that cURL shows the version of the curve and certificate when using the `-v` verbose mode of operation. This to simplify the procedure to verify that the intended curves are used. 

Last-not-least: OpenSSL was built using the `-DOQS_DEFAULT_GROUPS` option to specify the default list of curves. It is important to understand that in TLSv1.3, if `client preference` is specified in the server, the first curve in the list is used which the server also understands, if no `--curves` was explicitly specified.

The command line executable is found as `/opt/quantum_safe_crypto/bin/curl_QSC` inside the container.

Note: The option to use the `--curves` parameter on the CLI was added to upsream in the latest version. We'll reflect this by removing the related patch here in a later release. 

How to build: 
```docker build -f DockerfileWithPatch -t curl .```

How to test against [OQS QSC-test-server](https://test.openquantumsafe.org/): 
```
docker run -it curl
PS1='\u@\h:\w\$ '
curl_executable=/opt/quantum_safe_crypto/bin/curl_QSC
$curl_executable -v -k --curves prime256v1  https://test.openquantumsafe.org:6000
$curl_executable -v -k --curves X25519 https://test.openquantumsafe.org:6001
$curl_executable -v -k --curves prime256v1 https://nzz.ch
$curl_executable -v -k --curves secp521r1 https://nzz.ch

$curl_executable -v -k --curves kyber512 https://test.openquantumsafe.org:6013 
$curl_executable -v -k --curves kyber512 https://test.openquantumsafe.org:6090 
$curl_executable -v -k --curves kyber1024 https://test.openquantumsafe.org:6015
$curl_executable -v -k --curves p256_kyber512 https://test.openquantumsafe.org:6050
$curl_executable -v -k --curves kyber512 https://test.openquantumsafe.org:7322
$curl_executable -v -k --curves p256_kyber512 https://test.openquantumsafe.org:7205
$curl_executable -v -k --curves kyber512 https://test.openquantumsafe.org:7245
$curl_executable -v -k --curves p521_kyber90s1024 https://test.openquantumsafe.org:7302

$curl_executable -v -k --curves kyber1024 https://test.openquantumsafe.org:6246
```

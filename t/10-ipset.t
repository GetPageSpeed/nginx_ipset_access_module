use Test::Nginx::Socket -no_plan;

run_tests();

__DATA__

=== TEST: whitelist allows localhost
--- init
    # ensure the ipset exists and has 127.0.0.1
    system("ipset create testset hash:ip family inet") == 0 || die "create failed";
    system("ipset flush testset") == 0;
    system("ipset add testset 127.0.0.1") == 0 || die "add failed";
--- config
    # enable realip module to trust X-Real-IP from localhost
    real_ip_header   X-Real-IP;
    set_real_ip_from 127.0.0.0/8;

    ipset_access on;
    whitelist   testset;

    location / {
        return 200 'OK';
    }
--- request
    GET / HTTP/1.1
    Host: 127.0.0.1
--- response_body
OK

=== TEST: whitelist rejects other IP
--- init
    # keep testset containing only loopback
    system("ipset flush testset") == 0;
--- config
    real_ip_header   X-Real-IP;
    set_real_ip_from 127.0.0.0/8;

    ipset_access on;
    whitelist   testset;

    location / {
        return 200 'OK';
    }
--- request
    GET / HTTP/1.1
    Host: 127.0.0.1
    X-Real-IP: 203.0.113.5
--- response_status: 403

=== TEST: blacklist blocks localhost
--- init
    system("ipset flush testset") == 0;
    system("ipset add testset 127.0.0.1") == 0;
--- config
    real_ip_header   X-Real-IP;
    set_real_ip_from 127.0.0.0/8;

    ipset_access on;
    blacklist   testset;

    location / {
        return 200 'OK';
    }
--- request
    GET / HTTP/1.1
    Host: 127.0.0.1
--- response_status: 403

=== TEST: blacklist allows other IP
--- init
    system("ipset flush testset") == 0;
--- config
    real_ip_header   X-Real-IP;
    set_real_ip_from 127.0.0.0/8;

    ipset_access on;
    blacklist   testset;

    location / {
        return 200 'OK';
    }
--- request
    GET / HTTP/1.1
    Host: 127.0.0.1
    X-Real-IP: 203.0.113.5
--- response_body
OK

**free 

/if not defined(SOCKET_H)
/define SOCKET_H

dcl-ds SocketAddr;
   sin_family int(5:0);
   sin_port  uns(5:0);
   sin_addr uns(10:0);
   sin_zero char(8) inz(*allx'00');
end-ds;

dcl-s SocketAddrLen int(10:0);
dcl-s SocketAddrLena pointer inz(%addr(SocketAddrLen));
dcl-s HostEnta pointer;

dcl-ds HostEnt align based(HostEnta);
   h_namea    pointer;
   h_aliases pointer;
   h_addrtype int(10:0);
   h_len     int(10:0);
   h_addr_list pointer;
end-ds;

dcl-s HostEntDataa pointer;

dcl-ds HostEntData align based(HostEntDataa);
   h_name     char(256);
   h_aliases2 pointer dim(65);
   h_aliases2_ char(256) dim(64);
   h_addra    pointer dim(101);
   h_addr     uns(10:0) dim(100);
   open_flag  int(10:0);
   f0a       pointer;
   filep0    char(260);
   reserved0 char(150);
   f1a       pointer;
   filep1    char(260);
   reserved1 char(150);
   f2a       pointer;
   filep2    char(260);
   reserved2 char(150);
end-ds;


dcl-c AF_UNIX 1;
dcl-c AF_INET 2;
dcl-c AF_NS 6;
dcl-c AF_TELEPHONY 99;
dcl-c SOCK_STREAM 1;
dcl-c SOCK_DGRAM 2;
dcl-c SOCK_RAW 3;
dcl-c SOCK_SEQPACKET 5;
dcl-c SOL_SOCKET -1;
dcl-c SO_BROADCAST 5;
dcl-c SO_DEBUG 10;
dcl-c SO_DONTROUTE 15;
dcl-c SO_ERROR 20;
dcl-c SO_KEEPALIVE 25;
dcl-c SO_LINGER 30;
dcl-c SO_OOBINLINE 35;
dcl-c SO_RCVBUF 40;
dcl-c SO_RCVLOWAT 45;
dcl-c SO_REUSEADDR 55;
dcl-c SO_SNDBUF 60;
dcl-c SO_SNDLOWAT 65;
dcl-c SO_SNDTIMEO 70;
dcl-c SO_TYPE 75;
dcl-c SO_USELOOPBACK 80;
dcl-c INADDR_ANY 0;
dcl-c RC_OK 0;


dcl-pr socket int(10:0) extproc('socket');
   addr_family int(10:0) value;
   type int(10:0) value;
   protocol int(10:0) value;
end-pr;

dcl-pr set_socket_options int(10:0) extproc('setsockopt');
   socket_descriptor int(10:0) value;
   level int(10:0) value;
   option_name int(10:0) value;
   option_value pointer value;
   option_length int(10:0) value;
end-pr;

dcl-pr read int(10:0) extproc('read');
   socket_descriptor int(10:0) value;
   data pointer value;
   data_length int(10:0) value;
end-pr;

dcl-pr write int(10:0) extproc('write');
   socket_descriptor int(10:0) value;
   data pointer value;
   data_length int(10:0) value;
end-pr;

dcl-pr close_port extproc('close');
   socket_descriptor int(10:0) value;
end-pr;

dcl-pr connect int(10:0) extproc('connect');
   socket_descriptor int(10:0) value;
   address pointer value;
   address_length int(10:0) value;
end-pr;

dcl-pr bind int(10:0) extproc('bind');
   socket_descriptor int(10:0) value;
   local_address pointer value;
   address_length int(10:0) value;
end-pr;

dcl-pr listen int(10:0) extproc('listen');
   socket_descriptor int(10:0) value;
   max_clients int(10:0) value;
end-pr;

dcl-pr accept int(10:0) extproc('accept');
   socket_descriptor int(10:0) value;
   address pointer value;
   address_length pointer value;
end-pr;

dcl-pr inet_address int(10:0) extproc('inet_addr');
   ip_address pointer value;
end-pr;

dcl-pr get_host_by_name pointer extproc('gethostbyname');
   host_name pointer value;
end-pr;

dcl-pr get_host_by_addr pointer extproc('gethostbyaddr');
   host_address pointer value;
   address_length int(10:0) value;
   address_type int(10:0) value;
end-pr;

/endif
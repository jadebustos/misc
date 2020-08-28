#! /usr/bin/perl -w

# Determinacion dinamica de los dns's que funcionan bajo GNU/Linux

# Se supondra que estaran en la red 192.168.0.xxx

$PATH="/root/dinamicDNS/";
$PATRON="named.custom.patron";

$DELAY=120;            # Retardo en segundos
$NETWORK="192.168.0."; # Red
$FIRST=120;            # Primer ordenador en la red
$LAST=136;             # Ultimo ordenador en la red

@file=();

open FILE,$PATH.$PATRON;

@file=<FILE>;

close FILE;

do {

    @forwarders=("\tforwarders { ");
    $diferencias="";
    $i=$FIRST;

    while ($i <= $LAST) {

	$ip=$NETWORK."$i";

	if ( $i == 121 ) { # Saltamos el 121 que es el servidor
	    $i += 1;
	    $ip=$NETWORK."$i";
	}

	$resultado=`nmap -O -p 53 $ip`;

        # El sistema operativo es Linux?
	$so = $resultado =~ /Linux/;

	if ( $so != 0) {

            # Se esta ejecutando Bind? 
	    $named = $resultado =~ /53\/tcp/;

	    if ( $named != 0) {

		push (@forwarders,$ip."; ");

	    }
	}

	$i +=1;

    }

    push (@forwarders,"};\n};");

    # Creamos el fichero
    $nuevo=$PATH."named.custom.new";
    open FILE,">".$nuevo;
    print FILE @file;
    print FILE @forwarders;
    close FILE;

    # Comparamos el fichero nuevo con /etc/named.custom
    $diferencias=`diff $nuevo /etc/named.custom`;
    
    if ($diferencias ne "" ) {
        # Creamos el nuevo fichero /etc/named.custom y reiniciamos named
	system("cat $nuevo > /etc/named.custom");
	system("killall named");
	system("/etc/init.d/named start");
      
    }

#    system ("rm $nuevo");

    sleep($DELAY);

} until $i <= 7;

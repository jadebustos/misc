package PersonalPerlLibrary::Mail;

use strict;

use File::Type;
use Mail::IMAPClient;
use PersonalPerlLibrary::FS;

use Exporter;
use vars qw($VERSION @EXPORT @ISA);

@ISA = ('Exporter');
@EXPORT = qw (&connect_imap &create_imap_folders &create_user_spool_dir &get_email_from_rfc822_message &get_email_from_file &get_folders_from_directory &get_folder_from_filename &get_email_from_draft_file &get_email_from_sent_file &get_email_from_sent_folder &get_mail_msgs_from_dir &get_msgid &get_user_inbox_dir &is_file_a_sent_message &is_file_smtp_message &validate_email);
$VERSION='0.16';

###########################################################
# Funcion que establece una conexion con el servidor IMAP #
###########################################################

sub connect_imap { # BEGIN connect_imap
	# $imapServer -> Servidor IMAP
	# $port       -> Puerto
	# $user       -> Usuario
	# $password   -> Password
	my ($imapServer,$port,$user,$password) = @_;

	my $con=Mail::IMAPClient->new();
        	$con->Server($imapServer);
	        $con->Port($port);
	        $con->User($user);
	        $con->Password($password);
	        $con->connect();

	return $con;

} # END connect_imap

#############################################################
# Funcion que comprueba las folder de un usuario y las crea #
# de no existir                                             #
#############################################################

sub create_imap_folders { # BEGIN create_imap_folders
	# $folders -> array con el nombre de las carpetas
	# $imap    -> conexion con el servidor imap
	my ($folders,$imap) = @_;

	foreach my $item (@$folders) { # BEGIN foreach
		next if $item eq "INBOX";
		$imap->exists($item) or $imap->create($item);
	} # END foreach

} # END create_imap_folders

########################################################
# Function for creating spool_dir for an user. It only #
# creates INBOX.                                       #
########################################################

sub create_user_spool_dir { # BEGIN create_user_spool_dir
  # $path            -> directory to create
  # $path_perm       -> permissions for path 
  # $inside_dir_perm -> permissions for inside directories
  # $uid             -> uid to assign
  # $gid             -> gid to assign
  my ($base_dir, $base_dir_perm, $inside_dir_perm, $uid, $gid) = @_;
  my $inside_dir;

  $base_dir = check_dir_path($base_dir);

  system("mkdir -p -m $base_dir_perm $base_dir") if ! -d $base_dir;
  $inside_dir = $base_dir."new";
  system("mkdir -p -m $inside_dir_perm $inside_dir") if ! -d $inside_dir;
  $inside_dir = $base_dir."cur";
  system("mkdir -p -m $inside_dir_perm $inside_dir") if ! -d $inside_dir;
  $inside_dir = $base_dir."tmp";
  system("mkdir -p -m $inside_dir_perm $inside_dir") if ! -d $inside_dir;
  $inside_dir = $base_dir."courierimapkeywords";
  system("mkdir -p -m $inside_dir_perm $inside_dir") if ! -d $inside_dir;

  system("chown -R $uid:$gid $base_dir");
  
} # END create_user_spool_dir

############################################################
# Funcion que busca un fichero con formato rfc822 y extrae #
# de el la direccion de correo del destinatario            #
############################################################

sub get_email_from_rfc822_message { # BEGIN get_email_from_rfc822_message
  # $basedir -> directorio
  # $folders   -> folders validas para obtener la direccion de correo,
  #               seran del tipo INBOX, .Draft, ...
  my ($basedir,$folders) = @_;

  my @tmpfiles = get_files_from_directory($basedir);
  my @files = ();
  my @tmp = ();
  my $email = '';
  my $folder = "INBOX";

  # Solo consideraremos validos para la extraccion del
  # destinatario a aquellos que esten en el @folders

  foreach my $msg ( @tmpfiles ) { # BEGIN first foreach
    $folder = get_folder_from_filename($msg);
    if ( grep { /$folder/ } @$folders ) { # BEGIN if
        push @files,$msg;
    } # END if     

  } # END first foreach

  foreach my $msg (@files) { # BEGIN foreach
    if ( is_file_smtp_message($msg) != 0 ) { # BEGIN if
      $email = get_email_from_file($msg); 
      last if $email ne '';
    } # END if
  } # END foreach

 return $email;

} # END get_email_from_rfc822_message

############################################################
# Function that takes a file and returns the owner's email #
# when is not a .Sent or .Draft Mail                       #
############################################################

sub get_email_from_file { # BEGIN get_email_from_file
  # $file -> file to extract email address
  my ($file) = @_;

  my $email = "";

  open SMTPFILE,"< $file";
    foreach my $line (<SMTPFILE>) { # BEGIN foreach
      if ( $line =~ /^\w*-?To:/ ) { # BEGIN if
        $email=$line;
        $email =~ s/^\w*-?To:[\t ]*//;
        $email =~ s/.*<(.*)>.*/$1/g;
        $email =~ s/[\t\n ]*$//;
        last;
      } # END if
    } # END foreach
    close SMTPFILE;

  return $email;
} # END get_email_from_file

#########################################################
# Function tha takes a file inside Draft folder and gets #
# email address of the sender (owner)                   #
#########################################################

sub get_email_from_draft_file { # BEGIN get_email_from_draft_file
  # $file -> file to extract email address
  my ($file) = @_;

  my $email = "";

  open FILE,"< $file";
  foreach my $line (<FILE>) { # BEGIN second foreach
    if ( $line =~ /^From:/ ) { # BEGIN if
      $email=$line;
      $email =~ s/^From:[\t ]*//;
      $email =~ s/.*<(.*)>.*/$1/g;
      $email =~ s/[\t\n ]*$//;
      last;
    } # END if
    elsif ( $line =~ /^\w*-?To:/ ) { # BEGIN elsif
      $email=$line;
      $email =~ s/^\w*-?To:[\t ]*//;
      $email =~ s/.*<(.*)>.*/$1/g;
      $email =~ s/[\t\n ]*$//;
      last;     
    } # END elsif
  } # END second foreach
  close FILE;

  return $email;
} # END get_email_from_draft_file


#########################################################
# Function tha takes a file inside Sent folder and gets #
# email address of the sender (owner)                   #
#########################################################

sub get_email_from_sent_file { # BEGIN get_email_from_sent_file
  # $file -> file to extract email address
  my ($file) = @_;

  my $email = "";

  open FILE,"< $file";
  foreach my $line (<FILE>) { # BEGIN second foreach
    if ( $line =~ /^From:/ ) { # BEGIN if
      $email=$line;
      $email =~ s/^From:[\t ]*//;
      $email =~ s/.*<(.*)>.*/$1/g;
      $email =~ s/[\t\n ]*$//;
      last;
    } # END if
  } # END second foreach
  close FILE;

  return $email;
} # END get_email_from_sent_file

#
#
#

sub get_email_from_sent_folder { # BEGIN get_email_from_sent_folder
  # $ $dir -> directorio del forlder .Sent

  my ($dir) = @_;

  my @files = get_files_from_directory($dir);

  my $email  = "";

  foreach my $msg (@files) { # BEGIN first foreach
    open FILE,"< $msg";
    foreach my $line (<FILE>) { # BEGIN second foreach
      if ( $line =~ /^From:/ ) { # BEGIN if
        $email=$line;
        $email =~ s/^From:[\t ]*//;
        $email =~ s/.*<(.*)>.*/$1/g;
        $email =~ s/[\t\n ]*$//;
        last;
      } # END if
    } # END second foreach
    close FILE;
  } # END first foreach
  return $email;
  
} # END get_email_from_sent_folder

#########################################################
# Funcion que devuelve un array con los folders que hay #
# presentes en un directorio                            #
#########################################################

sub get_folders_from_directory { # BEGIN get_folders_from_directory
  # $directory -> directorio del usuario
  my ($directory) = @_;
  my @dirs;
  my @tmpfolders;
  my @folders;
  my @tmp;
  my $folder = "";
  my %items = ();

  @dirs = get_directories_from_directory($directory);

  push(@folders,"INBOX");

  foreach my $dir (@dirs) { # BEGIN first foreach

    @tmp = split /\//,$dir;
    $folder = (grep { /^\./ } @tmp)[0];
    push(@tmpfolders,"INBOX".$folder) if defined $folder;

  } # END first foreach

  # Eliminamos los elementos repetidos
  @folders = grep { ! $items{$_} ++} @tmpfolders;

  return @folders;

} # END get_folders_from_directory

###############################################################
# Funcion que devuelve el folder de un mensaje que se le pasa #
# por argumento. Utiliza "/" como indicativo de directorio.   #
###############################################################

sub get_folder_from_filename { # BEGIN get_folder_from_filename
  # $filename -> nombre del fichero
  my ($filename) = @_;

  my @tmp = split /\//,$filename;
  my $folder = "INBOX";
  my $token = "";

  foreach my $item (@tmp) { # BEGIN foreach
    last if $item eq "new" || $item eq "cur" || $item eq "tmp";
    # El folder es el elemento anterior
    $token = $item;
  } # END foreach

  $folder= $token if $token =~ /^\./;

  return $folder;

} # END get_folder_from_filename


############################################################
# Funcion que devuelve un con array los ficheros presentes #
# en un directorio que son mensajes de correo              #
############################################################

sub get_mail_msgs_from_dir { # BEGIN get_mail_msgs_from_dir
  # $dir -> directorio del que se extraen los mensajes

  my ($dir) = @_;

  my @files       = (); # mensajes de correo
  my @candidates  = ();

  $dir = check_dir_path($dir);

  @candidates = get_files_from_directory(check_dir_path($dir));

  foreach my $file (@candidates) { # BEGIN foreach
    my @tmp = split /\//,$file;
    push @files,$file if $tmp[$#tmp] =~ /^[\w\.]*,S=\d*/ || $tmp[$#tmp] =~ /^[\w\.]*web/;
  } # END foreach

  return @files;

} # END get_mail_msgs_from_dir

#################################################################
# Function that takes a file as its first arguments and returns #
# the Message-Id of the mail                                    #
#################################################################

sub get_msgid { # BEGIN get_msgid
  # $file -> file to extract Message-ID
  my ($file) = @_;

  my $msg_id = "";

  open FILE, "< $file";
    foreach my $line ( <FILE> ) { # BEGIN foreach
      if ( $line =~ /^Message-I[dD]/ ) { # BEGIN if
        $msg_id = $line;
        $msg_id =~ s/Message-I[Dd]:[\t ]*<//g;
        $msg_id =~ s/>//g;
        $msg_id =~ s/\n//g;
        close FILE;
        return $msg_id;
      } # END if
    } # END foreach

  close FILE;

  return $msg_id;
} # END get_msgid

###################################################################
# Function that returns the absolute path to main INBOX of a user #
###################################################################

sub get_user_inbox_dir { # BEGIN get_user_inbox_dir
  # $dir -> user directory
  my ($dir) = @_;
  my @dirs = get_directories_from_directory($dir);

  foreach my $item (@dirs) { # BEGIN foreach
    my @partes = split /\//,$item;
    my $user_inbox = "/";
    for(my $i=1;$i<=$#partes;$i++) { # BEGIN for
      if ( $partes[$i] =~ /^cur$/ || $partes[$i] =~ /^new$/ || $partes[$i] =~ /^tmp$/ ) { # BEGIN if
        return $user_inbox;                  
        } # END if
      else { # BEGIN else
        $user_inbox = $user_inbox.$partes[$i]."/";
        } # END else
      } # END for
  } # END foreach

} # END get_user_inbox_dir

##############################################################
# Funcion que comprueba si un fichero es un mensaje enviado, #
# ya que estos no se almacenan siguiendo el rfc822. Para     #
# detectarlos buscaremos una linea que empiece con:          #
# "User-Agent:"                                              #
##############################################################

sub is_file_a_sent_message { # BEGIN is_file_a_sent_message
	# $file -> mensaje a comprobar
	my ($file) = @_;

	open FILE,"< $file";
	
	foreach my $line (<FILE>) { # BEGIN foreach
		if ( $line =~ /^User-Agent:/ ) { # BEGIN if
			return 1; # SI LO ES
		} # END if
	} # END foreach

	close FILE;

	return 0; # NO LO ES	

} # END is_file_a_sent_message

##########################################################
# Funcion que comprueba si un fichero es un mensaje smtp #
##########################################################

sub is_file_smtp_message { # BEGIN is_file_smtp_message
	# $file -> mensaje a comprobar
	my ($file) = @_;	

	my $ft = File::Type->new();

	my $mime_type = $ft->mime_type($file);

	if ($mime_type !~ /^message\/rfc822$/) { # BEGIN if
		return 0; # NO LO ES
	} # END if

	return 1; # SI LO ES

} # END is_file_smtp_message


#######################################################
# This function validates an email address and return #
# a non zero value if characters like " and @ are     #
# present in user name.                               #
#######################################################

sub validate_email { # BEGIN validate_email
  # $email -> email to validate
  my ($email) = @_;
  my $status = 0; # right email address
  my @user_fields = split /\@/,$email;
  my $domain = (split /\@/,$email)[1];
  my @domain_parts = split /\./,$domain;

  # more than one @
  if ( $#user_fields ne 1 ) { # BEGIN if
    $status = 1;
  } # END if
  elsif ( $#domain_parts lt 1 ) { # BEGIN elsif
    $status = 1;
  } # END elsif

  elsif ( $email !~ /^([a-z]|[A-Z]|[0-9])[\w\.\-']*\w*@[\w\-\.]+$/ ) { # BEGIN e
lsif
    $status = 1;
  } # END elsif

  return $status;
} # END validate_email

1;

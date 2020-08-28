package PersonalPerlLibrary::FS;

use strict;
use File::Find;
use Digest::MD5;
use Exporter;
use vars qw($VERSION @EXPORT @ISA);

@ISA = ('Exporter');
@EXPORT = qw (&check_dir_path &erase_junk_files &generate_md5_hash &get_directory_list &get_directories_from_directory &get_files_from_directory);
$VERSION='0.02';

###############################################################
# Funcion que anyade "/" al final de la ruta de un directorio #
###############################################################

sub check_dir_path { # BEGIN check_dir_path
        # $path -> directorio
        my ($path)= @_;

        my $goodpath = $path;

        if ($goodpath !~ /\/$/ ) { # BEGIN if
                $goodpath=$goodpath."/";
        } # END if

        return $goodpath;

} # END check_dir_path

###################################################
# Funcion que borrar los ficheros de tamanyo cero #
###################################################

sub erase_junk_files { # BEGIN erase_junk_files
	# $path -> directorio del que borrar los ficheros en cuestion
	# $log_file -> fichero para logear lo que se borro

        my ($path,$log_file) = @_;
        my @files= get_files_from_directory($path);

        open LOG,"> $log_file" or die "No se pudo crear el fichero $log_file.\n";
        print LOG "Ficheros borrados:\n";

        foreach my $file (@files) { # BEGIN foreach
                if ( -z $file ) { # BEGIN if
                        system("rm -f $file");
                        print LOG "$file\n";
                } # END if
        } # END foreach

        close LOG;

} # END erase_junk_files

#####################################################################
# Funcion que recibe un array con nombres de ficheros y devuelve un #
# hash cuyas claves son las sumas md5 y los valores el nombre del   #
# fichero que tiene esa suma                                        #
#####################################################################

sub generate_md5_hash { # BEGIN generate_md5_hash
  # @datos -> datos para generar el hash
  my ($datos) = @_;
  my %hash = ();
  my $ctx = new Digest::MD5->new;
  my $md5sum = '';
  my @tmp = ();

  foreach my $item ( @$datos ) { # BEGIN foreach
    next if !defined ($item);
    open FILE,"$item";
    binmode(FILE);
    $ctx->addfile(*FILE); # hacemos el hashing del nombre del fichero
    $md5sum = $ctx->hexdigest;
    close FILE;
    $hash{$md5sum} = $item;
  } # END foreach
  return %hash;
} # END generate_md5_hash

##########################################################
# Funcion que devuelve los directorios, de primer nivel, #
# de uno dado                                            #
##########################################################

sub get_directory_list { # BEGIN get_directory_list
	# $domain      -> Directorio base para obtener su lista de
        #                 subdirectorios de primer nivel.
	# $directories -> Array donde escribir los directorios de 
        #                 primer nivel de $domain
	my ($domain,$directories) = @_;

	# Vaciamos $directories

        # Comprobar si existe $domain
        opendir(DIR,$domain) or return 0; # ERROR

        while ( defined (my $dir=readdir(DIR)) ) { # BEGIN while
                if (-d $domain.$dir){ # BEGIN if
                        push(@$directories,$dir) if $dir ne '.' && $dir ne '..';
                } # END if
        } # END while

        closedir(DIR);

	return 1;

} # END get_directory_list

###############################################################
# Function that retrieves al de subdirectories from one given #
###############################################################

sub get_directories_from_directory { # BEGIN get_directories_from_directory
  # $basedir -> directorio
  my ($basedir) = @_;

  my @directories = ();
  my @dir = ($basedir);

  find sub { push(@directories,$File::Find::name) if -d }, @dir;

  return @directories;

} # END get_directories_from directory

############################################################
# Funcion que devuelve todos los ficheros existentes en un #
# directorio                                               #
############################################################

sub get_files_from_directory { # BEGIN get_files_from_directory
	# $basedir -> directorio 
	my ($basedir) = @_;

	my @files = ();
	my @dir = ($basedir);

	find sub { push(@files,$File::Find::name) if -f }, @dir;

	return @files;

} # END get_files_from_directory

1;

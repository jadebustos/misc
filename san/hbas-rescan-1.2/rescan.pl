#!/usr/bin/perl -w

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
# You can get it from http://www.gnu.org/licenses/gpl.txt
#
# (c) Jose Angel de Bustos Perez <jadebustos@gmail.com>
#

# script para el rescaneo de los dispositivos asignados en la SAN
# necesario ya que hay veces que el powerpath no reconoce los dispositivos
# en el arranque

use strict;

my $hbadir = "/proc/scsi/qla2xxx/";
my @hbas;

opendir(DIR, $hbadir) or die "Error al abrir $hbadir.\n";
while (defined(my $file = readdir(DIR))) {
  push @hbas,$file if $file !~ /^\./;
}
closedir(DIR);

foreach my $id (@hbas) {

  `echo 1 > /sys/class/fc_host/host$id/issue_lip`;
  `echo "- - -" > /sys/class/scsi_host/host$id/scan`;

}

# esperamos 5 segundos
`sleep 5`;

# ejecutamos powermt
`powermt config`;

#!/usr/bin/env perl
#
#    This file is part of GrayBot.
#
#    GrayBot is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    GrayBot is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with GrayBot.  If not, see <http://www.gnu.org/licenses/>.
#

use warnings;
use strict;


#  Toutes les chaînes de caractères du script sont interprétées comme des chaînes de texte:
use utf8; # considère que le script doit être stocké en UTF-8
# Récupère les paramètres régionaux (les "locales") de l'environnement et
# demande à STDOUT de faire la conversion vers ces paramètres régionaux
use PerlIO::locale;
binmode STDOUT, ':locale';

# Toutes les entrées/sorties avec l'encodage courant
use open ':locale';

package Securebot;

use Crypt::Password;

sub new {
  my ($obj, $salt, $algo) = @_;
  my $self = {};

  if (!defined $salt) {
    use String::Random qw(random_string);
    $salt = random_string('..........');
  }

  $self->{'salt'} = $salt;
  $self->{'algo'} = $algo || 'sha512';
  return bless($self, $obj);
}

sub getSalt {
  my $self = shift;
  return $self->{'salt'};
}

sub getUserSalt {
  # Chaque user a son propre grain de sel.
  my $self = shift;
  my ($user) = @_;

  my @tmpB = split( /.{3}/, $user );
  my @tmpC = split( /.{2}/, $user );
  my @tmpA = split( //, $self->{'salt'} );

  my $biggest = ( sort { $b <=> $a } ($#tmpC, ( sort { $b <=> $a } ($#tmpA, $#tmpB) )[0]) )[0];

  my $userSalt = '';
  for (my $i = $biggest; $i>0; $i-- ) {
    $userSalt .= $tmpA[$i] if defined $tmpA[$i];
    $userSalt .= $tmpB[$i] if defined $tmpB[$i];
    $userSalt .= $tmpC[$i] if defined $tmpC[$i];
  }

  return $userSalt;
}

sub hash {
  my ($self, $nick, $password) = @_;
  return -1 unless defined $password;
  return password( $password, $self->getUserSalt($nick), $self->{'algo'} ) ;
}

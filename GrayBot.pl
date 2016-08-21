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






{
  package GrayBot;
  use base qw( Bot::BasicBot );

  use Data::Dumper;
  use List::Util 'first';
  use Securebot;

  our $gameDir = "$ENV{HOME}/.config/GrayBot";
  our $gameData = "$gameDir/config.data";




  sub init {
    my ($self) = shift;

    unless ( -d $gameDir ) {
      mkdir $gameDir;
    }

    # On charge la config.
    my $loaded = $self->loadGame();
    if ( $loaded ) {
      $self->debug('Unident all.');
      foreach my $user( keys %{ $self->{'Game'}->{'users'} } ) {
        $self->unidentUser($user);
      }
    }

    # Puis on crée une instance de Securebot pour permettre les identifications.
    if ( !defined $self->{'Game'}->{'config'}->{'salt'} ) {
      $self->debug('Pas de grain de sel. On en génère un.', -1);
      $self->{'secure'} = Securebot->new();
      $self->{'Game'}->{'config'}->{'salt'} = $self->{'secure'}->getSalt();
      $self->saveGame();
    } else {
      $self->{'secure'} = Securebot->new( $self->{'Game'}->{'config'}->{'salt'} );
    }

    return $loaded;
  }





  sub loadGame {
    my ($self) = shift;

    if ( ! -w $gameData ) {
      $self->debug('Pas de données de jeu ; on les crée.');
      $self->{'Game'} = {
        'bar' => {
             'GHB' => 65,
             'zizicoincoin' => 4,
             'badois' => 2,
             'whisky' => 5,
             'eau' => 0,
             'rhum' => 4,
             'coca cola' => 2,
             'vodka' => 3,
             'biere' => 2,
             'perrier' => 2,
             'orangina' => 2
           },
        'users' => {
            lc $self->{'nick'} => {
                'force' => 5000,
                'gris' => 1,
                'constitution' => 5000,
                'alcoolisme' => 50,
                'sagesse' => 1,
                'karma' => 100,
                'vie' => 100,
                'souplesse' => 5000,
              },
          },
        'config'  => {
            'coef'        => {
                'randGris'    => 0.5,
                'count'       => 4,
              },
            'nick_freeze' => 0,
            'spymode'     => 1,
            'debug'       => 20,
            },
        'tick'    => 300, # 5 minutes
        'action'  => 0,
        'masters' => ['Luvwahraan'],
        'combat'  => [],
      };
      $self->saveGame();
    } else {
      $self->debug('Chargement des donnée de jeu.');
      $self->{'Game'} = do( $gameData );
      $self->{'Game'}->{'config'}->{'action'} = 0;
      $self->debug(Dumper($self->{'Game'}), 100);
    }
    return 1;
  }




  sub saveGame {
    my $self = shift;
    $self->debug('Écriture des données de jeu.');

    open(my $FH, ">$gameData") or return "$gameData illisible";
    print $FH Dumper( $self->{'Game'} );
    close $FH;

    $self->debug(Dumper($self->{'Game'}), 100);

    return 'Configuration écrite.';
  }




  sub debug {
    my ($self, $msg, $lvl) = @_;

    # Niveau de debug mini pour être bavard.
    $lvl = $lvl || 1;

    # Si rien dans la config, on l’ajoute.
    if ( !defined $self->{'config'}->{'debug'} ) {
      $self->{'config'}->{'debug'} = 50;
      $self->{'Game'}->{'config'}->{'action'} = 1;
    }

    return unless $self->{'config'}->{'debug'} >= $lvl;
    print "DBG\t$msg\n";
  }





  sub identUser {
    my $self = shift;
    $self->debug('Ident : '.Dumper \@_);
    my ($nick, $password) = @_;

    if (!defined $password) {
      $self->say( who => $nick, channel => 'msg', body => 'Et le mot de passe ?' );
    }

    $nick = lc $nick;
    if ( $self->checkPassword($nick, $password) ) {
      $self->say( who => $nick, channel => 'msg', body => 'Effectivement, c’est toi.' );
      $self->{'Game'}->{'users'}->{$nick}->{'identified'} = 1;

    } else {
      $self->say( who => $nick, channel => 'msg', body => 'Non c’est pas toi.' );
    }
  }




  sub unidentUser {
    my ($self, $nick) = @_;
    $nick = lc $nick;
    $self->debug("Désidentifie $nick.");
    $self->{'Game'}->{'users'}->{$nick}->{'identified'} = 0;
  }




  sub changePassword {
    my $self = shift;
    $self->debug('Change password : '.Dumper \@_);
    my ($nick, $password, $newPassord) = @_;

    if ( !defined $self->{'Game'}->{'users'}->{$nick}->{'password'} or checkPassword($nick, $password ) ) {
      $password = $self->validPassword($nick, $newPassord);
      $self->say( who => $nick, channel => 'msg', body => 'Effectivement, c’est toi.' );
    } else {
      $self->say( who => $nick, channel => 'msg', body => 'Mot de passe invalide.' );
    }
  }




  sub  validPassword {
    my $self = shift;
    $self->debug('Wipe USER : '.Dumper \@_);
    my ($nick, $password) = @_;

    if ( !defined $password ) {
      use String::Random qw(random_string);
      $password = random_string('.....');
      $self->say(
        who     => $nick,
        channel => 'msg',
        body    => 'Tu n’as pas choisi de mot de passe, une chaîne aléatoire a donc '.
            'été générée. Voici ton mot de passe :',
     );
      $self->say(
        who     => $nick,
        channel => 'msg',
        body    => $password,
     );
    }

    if (length($password) < 5 ) {
        $self->say(
          who     => $nick,
          channel => 'msg',
          body    => 'Le mot de passe est trop court. Cinq caractères sont nécéssaires.',
       );
       return;
    }

    return $self->{'secure'}->hash($nick, $password);
  }




  sub wipeUser {
    my $self = shift;
    $self->debug('Wipe USER : '.Dumper \@_);
    my ($nick, $password, $newPassord) = @_;

    if ( !defined $self->{'Game'}->{'users'}->{$nick}->{'password'} or checkPassword($nick, $password ) ){
      $self->newUser( $nick, $newPassord, 1 );
    } else {
      $self->say( who => $nick, channel => 'msg', body => 'Mot de passe invalide.' );
    }
  }




  sub checkPassword {
    my $self = shift;
    $self->debug('Vérification mod de passe : '.Dumper \@_, 8);
    my ($nick, $password) = @_;
    $nick = lc $nick;

    if ( $self->{'Game'}->{'users'}->{$nick}->{'password'} eq $self->{'secure'}->hash($nick, $password) ) {
      return 1;
    } else {
      return 0;
    }
  }





  sub newUser {
    my $self = shift;
    $self->debug("Nouveau joueur : ".Dumper \@_);
    my ($nick, $password, $force) = @_;
    $nick = lc $nick;

    unless (defined $force) {
      if ( defined( $self->{'Game'}->{'users'}->{$nick} ) ) {
        $self->say(
          who     => $nick,
          channel => 'msg',
          body    => 'Ton personnage existe déjà.',
       );
       return -1;
      }
    }

    $password = validPassword( $nick, $password );
    return -2 unless $password;

    $self->{'Game'}->{'users'}->{$nick}->{'password'} = $password;
    $self->randomUserData($nick);

    my $msg = 'Ton personnage vient d’être créé, avec des Gris (monnaie du jeu) et des ';
    $msg .= 'compétences raisonnablement aléatoires, que tu peux voir à l’aide des ';
    $msg .= 'commande !gris et !stats. Une liste succinte des commandes est disponible ';
    $msg .= 'en tapant !aide.';
    $self->say( who => $nick, channel => 'msg', body => $msg );

    $msg = 'Notes bien ton mot de passe ; ce dernier n’est pas récupérable si tu l’oublies.';
    $self->say( who => $nick, channel => 'msg', body => $msg );

    $msg = 'Tu peux maintenant t’identifier avec la commande « !itsmi MOTDEPASSE ».';
    $self->say( who => $nick, channel => 'msg', body => $msg );

    $msg = 'Notes par ailleurs que le jeu continue tant que je suis présent, mais qu’il ';
    $msg .= 'faut être identifié pour utiliser les commandes (autres que !itsmi et !ouesh). ';
    $msg .= 'Les autres personnages peuvent donc intéragir avec le tiens, même si tu es absent.';
    $self->say( who => $nick, channel => 'msg', body => $msg );

    $self->{'Game'}->{'users'}->{$nick}->{'identified'} = 1;

  }




  sub randomUserData {
    my ($self, $nick) = @_;
    $nick = lc $nick;

    $self->debug("Random for $nick");
    my $minGris = 15;

    my @skills = ('force', 'sagesse', 'constitution');
    $self->{'Game'}->{'users'}->{$nick}->{'gris'} = $self->{'Game'}->{'users'}->{$nick}->{'gris'} | 0;
    $self->{'Game'}->{'users'}->{$nick}->{'gris'} += $minGris + int (rand 4*$minGris);
    $self->{'Game'}->{'users'}->{$nick}->{'alcoolisme'} = 0;
    $self->{'Game'}->{'users'}->{$nick}->{'vie'} = 100;
    $self->{'Game'}->{'users'}->{$nick}->{'karma'} = 100;

    foreach (@skills) {
      $self->{'Game'}->{'users'}->{$nick}->{ $_ } = 1;

    }

    for (my $points = 9; $points > 0; $points-- ) {
      $self->{'Game'}->{'users'}->{$nick}->{ $skills[ rand @skills ] }++;
    }


    $self->debug( Dumper $self->{'Game'}->{'users'});
    $self->saveGame();
  }




  sub getAlcoolisme {
    my ($self, $nick) = @_;
    $nick = lc $nick;
    return $self->{'Game'}->{'users'}->{$nick}->{'alcoolisme'};
  }




  sub hurt {
    my ($self, $nick, $nb) = @_;
    $nick = lc $nick;
    $nb = $nb | 1;

    $self->{'Game'}->{'users'}->{$nick}->{'vie'} -= $nb;
  }



  sub heal {
    my ($self, $nick, $nb) = @_;
    $nick = lc $nick;
    $nb = $nb | 1;

    $self->{'Game'}->{'users'}->{$nick}->{'vie'} += $nb;
  }



  sub incKarma {
    my ($self, $nick) = @_;
    $nick = lc $nick;
    $self->{'Game'}->{'users'}->{$nick}->{'karma'}++;
  }




  sub decKarma {
    my ($self, $nick) = @_;
    $nick = lc $nick;
    unless ( $self->{'Game'}->{'users'}->{$nick}->{'karma'} <= 0 ) {
      $self->{'Game'}->{'users'}->{$nick}->{'karma'}++;
    }
  }




  sub verifGris {
    my ($self, $nick) = @_;
    $nick = lc $nick;
    if ( $self->{'Game'}->{'users'}->{$nick}->{'gris'} <= 0 ) {
      $self->{'Game'}->{'users'}->{$nick}->{'gris'} = 0;
    }
  }




  sub addGris {
    my ($self, $nick, $euro) = @_;
    $euro = $euro || 1;

    if ( $euro >= 0 ) {
      $self->{'Game'}->{'users'}->{$nick}->{'gris'} += $euro;
      $self->verifGris($nick);
    }
  }




  sub delGris {
    my ($self, $nick, $euro) = @_;
    $nick = lc $nick;
    $euro = $euro || 1;

    if ( $euro >= 0 ) {
      $self->{'Game'}->{'users'}->{$nick}->{'gris'} -= $euro;
      $self->verifGris($nick);
    }
  }




  sub getGris {
    my ($self, $nick) = @_;
    $nick = lc $nick;
    #$self->debug("Get gris : ".Dumper($self->{'Game'}->{'users'}->{$nick}));
    return $self->{'Game'}->{'users'}->{$nick}->{'gris'};
  }




  sub chanjoin {
    my ($self, $message) = @_;

    return if ( $message->{'who'} eq $self->{'nick'} );
    return unless ( lc $message->{'channel'} eq lc $self->{'actif'} );

    my $msg = '';

    if ( $message->{'body'} eq 'chanjoin' ) {
      # On regarde si on connaît l’utilisation.
      unless ( defined( $self->{'Game'}->{'users'}->{$message->{'who'}} ) ) {
        $msg .= 'Bienvenue chez les dingues ! ';
        $msg .= 'Pour jouer dis-moi « !ouesh » suivi d’un mot de passe que tu choisis, en privé.';
        return $msg;
      }

      $self->say(
        channel => $message->{'channel'},
        body    => 'Tiens ! Mais c’est '.$message->{'who'}.' que re’vlà !',
       );

      return;
    }

    # Petits bonus de connexion.
    if ( $self->getGris($message->{'who'}) <= 100 ) {
      $self->addGris($message->{'who'}, 10);
    }
    if ( $self->getGris($message->{'who'}) <= 500 ) {
      $self->addGris($message->{'who'}, 5);
    }
    incKarma($message->{'who'});

    return;
  }




  sub barHandler {
    my $self = shift;
    $self->debug('Bar : '.Dumper\@_);
    my ($nick, $channel, $data) = @_;
    $nick = lc $nick;

    unless (defined $data) {
      $self->debug('On donne les boissons.');
      $self->say( channel => $channel, body => 'Les boissons disponibles sont :' );
      foreach my $drink( sort keys %{$self->{'Game'}->{'bar'}} ) {
        $self->say(
          channel => $self->{'actif'},
          body    => "$drink − $self->{Game}->{bar}->{$drink} Gris"
         );
      }

      $self->say(
          channel => $self->{'actif'},
        body    => 'Attention, l’abus d’alcool est dangereux pour votre entourage.'
       );

       return;
    }

    my ($rawDrink,$target) = split(' ', $data);

    my $drink = first { /$rawDrink/i } keys( %{$self->{'Game'}->{'bar'}});

    $self->debug("Bar : $nick, $channel, $rawDrink, $drink");

    if ( $drink ) {
      $self->debug('Quelqu’un va picoler.');
      $self->debug("alcoolisque $nick : ".$self->getAlcoolisme($nick),"\n");

      # Plus le joueur est alcoolisé, plus il sera succeptible de donner d’argent en trop.
      #my $alcoolisme = int( rand($self->getAlcoolisme($nick)) );
      my $price = $self->{'bar'}->{$drink};
      $price += int( rand($self->getAlcoolisme($nick)) );

      if ( $self->getGris($nick) < $self->{'Game'}->{'bar'}->{$drink} ) {
        $self->say(
          channel => $self->{'actif'},
          body    => "C’est sympa de picoler $nick, mais encore faut-il avoir les moyens."
         );
         return;
      }


      $self->delGris($nick, $price );

      # On offre une boisson, ou c’est pour soit…
      if ( defined $target ) {
        $self->debug("Boisson pour $target");

        # Si l’user a un personnage, on gère l’alcoolisme.
        if ( defined $self->{'Game'}->{'users'}->{$target} ) {
          $self->{'Game'}->{'users'}->{$target}->{'alcoolisme'} += $self->{'Game'}->{'bar'}->{$target} - 1;
        }
        $self->emote(
          channel => $self->{'actif'},
          body    => 'sert '.$drink.' à '.$target.'. Ça fera '.$self->{'Game'}->{'bar'}->{$drink}.'G.'
        );
      } else {
        $self->{'Game'}->{'users'}->{$nick}->{'alcoolisme'} += $self->{'Game'}->{'bar'}->{$drink} - 1;
        $self->emote(
          channel => $self->{'actif'},
          body    => 'sert '.$drink.' à '.$nick.'. Ça fera '.$self->{'Game'}->{'bar'}->{$drink}.'G.'
         );
      }

    } elsif ( $rawDrink =~ /cocaïne/i ) {
      # Fonction cachée. Peut mal tourner pour le joueur.
      $self->debug('Cocaïne.');

      my $action = int rand(3);

      if ( $action == 0 ) {
        $self->delGris($nick, 410 );
        $self->{'Game'}->{'users'}->{$nick}->{'alcoolisme'} += 500;
        $self->emote(
          channel => $self->{'actif'},
          body    => "emmène discretement $nick dans les toilettes, et lui fait ligne de coke, ".
              "avant de repartir avec son pognon."
         );
      } elsif ( $action == 1 ) {
        $self->delGris($nick, 10000 );
        $self->hurt($nick, 25);
        $self->emote(
          channel => $self->{'actif'},
          body    => "emmène discretement $nick dans les toilettes et repart avec toutes ses thunes, ".
              "après l’avoir tabassé."
         );
      } elsif ( $action == 2 ) {
        $self->delGris($nick, 410 );
        $self->{'Game'}->{'users'}->{$nick}->{'alcoolisme'} += 5000;
        $self->hurt($nick, 60);
        $self->delGris($nick, 410);
        $self->emote(
          channel => $self->{'actif'},
          body    => "emmène discretement $nick dans les toilettes et s’en va en vitesse, ".
              "pendant son overdose de coke."
         );
      }

    } else {
      $self->say(
        channel => $self->{'actif'},
        body    => "Qu’est-ce que c’est que cette boisson ? $rawDrink ? Jamais entendu parler."
       );

    }
  }




  sub setDebug {
    my $self = shift;
    my $nb = $data || 0;

    $self->{'Game'}->{'config'}->{'debug'} = $data;

    # Témoins pour la sauvegarde auto.
    $self->{'Game'}->{'config'}->{'action'} = 1;
    return $self->{'Game'}->{'config'}->{'debug'};
  }




  sub toggleSpyMode {
    my $self = shift;

    if ( defined $self->{'Game'}->{'config'}->{'spymode'} and
        $self->{'Game'}->{'config'}->{'spymode'} == 1 ) {
      $self->{'Game'}->{'config'}->{'spymode'} = 0;
    } else {
      $self->{'Game'}->{'config'}->{'spymode'} = 1;
    }

    # Témoins pour la sauvegarde auto.
    $self->{'Game'}->{'config'}->{'action'} = 1;
    return $self->{'Game'}->{'config'}->{'spymode'};
  }




  sub userStats {
    my ($self, $nick) = @_;
    $nick = lc $nick;

    $self->say(
        who     => $nick,
        channel => 'msg',
        body    => 'Voici tes statistiques :',
     );
    foreach my $stat( keys %{$self->{'Game'}->{'users'}->{$nick}} ) {
      $self->say(
          who     => $nick,
          channel => 'msg',
          body    => "$stat : ".$self->{'Game'}->{'users'}->{$nick}->{$stat},
       );
    }
  }




  sub deleteUser {
    my $self = shift;
    $self->debug( 'Delete user : '.Dumper \@_ );
    my $nick = shift;

    if ( defined $self->{'Game'}->{'users'}->{$nick} ) {
      delete $self->{'Game'}->{'users'}->{$nick};
      $self->say( channel => $self->{'actif'}, body => "$nick vient de disparaître. ):" );
    }
  }




  sub getRandPlayer {
    my $self = shift;
    my @players = keys( %{$self->{'Game'}->{'users'}} );
    return $players[ rand( $#players ) ];
  }




  sub donGris {
    my $self = shift;
    my ($nick, $data) = @_;
    $nick = lc $nick;

    unless ( defined $data ) {
      $self->emote(
          channel => $self->{'actif'},
          body    => "fait un bisou à $nick.",
       );
       return;
    }

    my ($amount, $target) = split(' ', $data);


    unless (defined $target) {
      # Pas de cible… on donne à un joueur au hasard.
      $target = $self->getRandPlayer();
    }

    my $gris = $self->getGris($nick);
    if ( $gris < $amount ) {
      $self->say(
          channel => $self->{'actif'},
          body    => "$nick fait un don de ton ses Gris à $target.",
        );
      $self->delGris($nick, $gris );
      $self->addGris($target, $gris );
    } else {
      $self->delGris($nick, $amount);
      $self->addGris($target, $amount);
      $self->say(
          channel => $self->{'actif'},
          body    => "$nick fait un don de $amount Gris à $target.",
       );
    }
  }




  sub commandAdmin {
    my $self = shift;
    my ($nick, $channel, $cmd, $data) = @_;
    $nick = lc $nick;

    if ( $cmd eq 'save' ) {
      $self->say( channel => 'msg', who => $nick, body => $self->saveGame() );
    }
    elsif ( $cmd eq 'masterchief' ) {
      if ( defined $data) {
        $self->debug("Op $data", 5);
        $self->mode( $self->{'actif'}." +o $data");
      } else {
        $self->debug("Op $nick", 5);
        $self->mode( $self->{'actif'}." +o $nick");
      }
    }
    elsif ( $cmd eq 'chief' ) {
      if ( defined $data) {
        $self->debug("Op $data", 5);
        $self->mode( $self->{'actif'}." +h $data");
      } else {
        $self->debug("Op $nick", 5);
        $self->mode( $self->{'actif'}." +h $nick");
      }
    }
    elsif ( $cmd eq 'believer' ) {
      if ( defined $data) {
        $self->debug("Op $data", 5);
        $self->mode( $self->{'actif'}." +v $data");
      } else {
        $self->debug("Op $nick", 5);
        $self->mode( $self->{'actif'}." +v $nick");
      }
    }
    elsif ( $cmd eq 'kasstoa' ) {
      if ( defined $data) {
        $self->debug("Kick $data", 5);
        $self->kick( $self->{'actif'}, $data);
      } else {
        $self->debug('Arrêt du jeu.');
        $self->saveGame();
      }
      exit(0);
    }
    elsif ( $cmd eq 'delete' ) {
      $self->userDelete($data);
    }
    elsif ( $cmd eq 'reload' ) {
      $self->loadGame();
    }
    elsif ( $cmd eq 'join' ) {
      $self->join($data);
    }
    elsif ( $cmd eq 'part' ) {
      $self->part($data);
    }
    elsif ( $cmd eq 'debug' ) {
      if ( $data =~ /\d+/ ) {
        $self->debug('Toggle debugmode', 10);
        $self->setDebug($data);
      }

    }
    elsif ( $cmd eq 'spymode' ) {
      $self->debug('Toggle spymode', 10);
      $self->toggleSpyMode();
    }
    elsif ( $cmd eq 'tick' ) {
      $self->debug('Change tick', 10);
      if ( $data =~ /(\d+)/ ) {
        $self->{'Game'}->{'config'}->{'tick'} = $1;
        $self->say( channel => 'msg', who => $nick, body => "Tick défini à $1.");
      }
    }
    elsif ( $cmd eq 'say' ) {
      if ( defined $data) {
        $self->debug("BotMSG $data", 5);
        $self->say( channel => $self->{'actif'}, body => $data);
      } else {
        $self->debug("BotMSG");
        $self->say( channel => $self->{'actif'}, body => 'Je suis une loutre.');
      }
    }
    elsif ( $cmd eq 'act' ) {
      if ( defined $data) {
        $self->debug("BotACT $data", 5);
        $self->emote( channel => $self->{'actif'}, body => $data);
      } else {
        $self->debug("BotACT", 5);
        $self->emote( channel => $self->{'actif'}, body => 'est une loutre.');
      }
    }
    else {
      # Pas de commande, ou elle est invalide.
      return 0;
    }

    return 1;
  }




  sub commandHandler {
    my $self = shift;
    $self->debug("Commande :".Dumper \@_, 3);
    my ($nick, $channel, $cmd, $data) = @_;
    $nick = lc $nick;
    $cmd = lc $cmd;


    study $cmd;

    # Commandes disponibles hors connexion.
    if ( $cmd eq 'ouesh' ) {
      $self->newUser($nick, $data);
      return;
    } elsif ( $cmd eq 'itsmi' ) {
      $self->identUser($nick, $data);
      return;
    }

    # À partir de là, il faut être identifié.
    return unless ( defined $self->{'Game'}->{'users'}->{$nick}
        and $self->{'Game'}->{'users'}->{$nick}->{'identified'} );


    $self->debug("Commande par un user identifié : $nick", 2);


    # Commandes admin.
    foreach my $admin( @{ $self->{'Game'}->{'masters'} } ) {
      $self->debug("Test admin: $admin vs $nick", 10);
      if ( $nick eq lc $admin ) {
        return if $self->commandAdmin($nick, $channel, $cmd, $data);
      }
    }

    # Autres commandes.
    if ( $cmd eq 'gris') {
      my $msg = 'Tu as '.$self->getGris($nick).'Gris en poche.';
      $msg .= ' Il serait quand même temps de les dépenser, pingre !' if ( $self->getGris($nick) > 10000);
      $self->say( who => $nick, channel => 'msg', body => $msg );
    }
    elsif ( $cmd eq 'bar' ) {
      $self->barHandler($nick, $channel, $data);
    }
    elsif ( $cmd eq 'stats' ) {
      $self->userStats($nick);
    }
    elsif ( $cmd =~ 'don(ne)?' ) {
      $self->debug('Commande donne.');
      $self->donGris($nick, $data);
    }
    elsif ( $cmd =~ 'f(rappe)?' ) {
      $self->debug('Début de baston.');
      $self->frappe($nick, $data);
    }
    elsif ( $cmd =~ 'esq(uive)?' ) {
      $self->debug('Début de baston.');
      $self->esquive($nick, $data);
    }
    elsif ( $cmd =~ 'cpami' ) {
      $self->unidentUser($nick);
    }
    elsif ( $cmd =~ 'wipe' ) {
      my ($password, $newPassord) = split (' ', $data);
      $self->wipeUser($nick, $password, $newPassord);
    }
    elsif ( $cmd =~ /help|aide/ ) {
      my @msg = ('Commande disponibles : ',
          '!bar : commander au bar',
          '!stats : voir tes statistiques',
          '!donne : faire un don de Gris',
          '!gris : voir tes Gris',
          '!frappe : frapper un personnage',
          '!esquive : esquiver une frappe',
          '!cpami : se déconnecter',
          );

      foreach my $m(@msg) {
        $self->say( who => $nick, channel => 'msg', body => $m );
      }
    }

    return;
  }





  sub frappe {
    my $self = shift;
    $self->debug('Frappe : '.Dumper \@_);
    my ($nick, $target) = @_;
    $nick = lc $nick;

    if ( !defined $target ) {
      $self->say( channel => $self->{'actif'},
        body => "Tu aimes frapper dans le vent, $nick ?" );
        return;
    }

    if ( defined $self->{'Game'}->{'users'}->{$target} ) {
      # On ajoute le combat à la liste.
      push( @{ $self->{'Game'}->{'combat'} }, { 'nick' => $nick, 'target' => $target } );

      $self->say( channel => $self->{'actif'},
        body => "$nick s’apprette à frapper $target…" );
    }
  }




  sub searchCombat {
    my ($self, $nick) = @_;
    $nick = lc $nick;

    foreach my $combat( @{ $self->{'Game'}->{'combat'} } ) {
      return $combat if ( lc $nick eq lc $self->{'Game'}->{'combat'}[$combat]->{'target'} )
    }

    return -1;
  }





  sub esquive {
    my $self = shift;
    $self->debug('Frappe : '.Dumper \@_);
    my ($nick, $target) = @_;
    $nick = lc $nick;

    my $combat = $self->searchCombat($nick);
    if ( $combat < 0 ) {
      # Pas d’aggresseur, rien à esquiver.
      $self->say( channel => $self->{'actif'},
        body => "Tu essaies de partir sans payer tes conso’, $nick ?" );
        return;
    }

    my $aggro = $self->{'Game'}->{'combat'}[$combat]->{'nick'};

    # Plus l’user est alcoolisé, moins il a de chance d’esquiver.
    if ( $self->getAlcoolisme($nick) > 0 ) {

    }

    pop( @{$self->{'Game'}->{'combat'}} );
    $self->say( channel => $self->{'actif'}, body => "$nick esquive l’aggression de $aggro" );
  }




  sub grisHandler {
    my ($self, $nick, $message, $channel) = @_;
    return unless defined $message;
    $nick = lc $nick;

    study $message;
    my $count = () = $message =~ /\p{L}/gi;
    my $bad = () = $message =~ /la|[dtlc]]['’]|aux?|les?|une?|des?|du|je|tu|il|nous|vous|ils|elle|elles|[aeiouy]h+|h[aeiouy]+|son|sa|ses|ces?|cette/gi;
    my $bonus = () = $message =~ /[zwàéèù’æ&ə°àâêîôûŷäëïöüÿ]|\(-?[|:;]/gi;
    my $superBonus = () = $message =~ /chat|Indigomoon|Ourse?s?|aigrie?s?|clitoris|moto|CB ?(500|750|four)/i;


    $count = ($count-$bad+$bonus+2*$superBonus) / ($self->{'Game'}->{'config'}->{'coef'}->{'count'});
    $count += $count*$self->{'Game'}->{'config'}->{'coef'}->{'randGris'};
    $count = 1 if $count <= 0;
    $self->addGris($nick, int $count);
  }




  sub said {
    my ($self, $message, $act) = @_;

    $message->{'who'} = lc $message->{'who'};

    if ( defined $self->{'Game'}->{'config'}->{'spymode'} and $self->{'Game'}->{'config'}->{'spymode'} > 0 ) {
      if ( defined $act and $act ) {
        print "$message->{channel}: $message->{who} $message->{body}\n";
      } else {
        print "<$message->{who}\@$message->{channel}> $message->{body}\n";
      }
    }


    if ( lc $message->{'channel'} eq lc $self->{'actif'} or $message->{'channel'} eq 'msg' ) {


      # Gestion commandes.
      if ( $message->{'body'} =~ s/^!//i ) {
        my ($cmd, $data) = split(' ', $message->{'body'}, 2);
        $self->commandHandler($message->{'who'}, $message->{'channel'}, $cmd, $data);
        return;
      }
    }

    return unless defined( $self->{'Game'}->{'users'}->{$message->{'who'}} );

    # Ajout l’argent.
    if ( defined( $self->{'Game'}->{'users'}->{$message->{'who'}} ) ) {
      $self->grisHandler($message->{'who'}, $message->{'body'}, $message->{'channel'});
    }

    # Témoins pour la sauvegarde auto.
    $self->{'Game'}->{'config'}->{'action'} = 1;
    return;
  }




  sub emoted {
    my $self = shift;
    return $self->said(@_,1);
  }




  sub chanpart {
    my $self = shift;
    $self->debug('Chan part : '.Dumper \@_);
    my ($nick) = @_;

    # On retire l’identification.
    $self->unidentUser( lc shift);
    return;
  }





  sub nick_change {
    my $self = shift;
    $self->debug('Nick change : '.Dumper \@_);
    my ($nick) = @_;

    # On retire l’identification.
    $self->unidentUser( lc shift);
    return;
  }




  sub names {
    my $self = shift;
    $self->debug('NAME '.Dumper @_);
  }




  sub tick {
    my $self = shift;
    my $tick = $self->{'Game'}->{'config'}->{'tick'} || 300;

    # Sauvegarde auto, s’il y a eu du changement.
    if (( defined $self->{'Game'}->{'config'}->{'action'} and $self->{'Game'}->{'config'}->{'action'} > 0)
          or !defined $self->{'Game'}->{'config'}->{'action'} ){
      $self->saveGame();
      $self->{'Game'}->{'config'}->{'action'} = 0;
    }

    # On réduit l’alcoolisme des joueurs.
    $self->debug('tick alcoolos');
    foreach my $nick( keys %{$self->{'Game'}->{'users'}} ) {
      $self->debug($nick);
      $self->{'Game'}->{'users'}->{$nick}->{'alcoolisme'}-- if ( $self->getAlcoolisme($nick) );
    }

    return $tick; # Attend 5 minutes
  }

}



my $nick = shift @ARGV || 'Motion';
my $channel = shift @ARGV || '#TestChan';

package main;
my $Bot = GrayBot->new(
    server    => 'irc.evolu7ion.fr',
    port      => '6667',
    channels  => [$channel],
    actif     => $channel,
    nick      => $nick,
    alt_nicks => ['Censure','Motsure'],
    username  => 'motsure',
    name      => 'Motion de censure',
    flood     => 1,
  );




$Bot->run();

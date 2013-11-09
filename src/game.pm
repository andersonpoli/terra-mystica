#!/usr/bin/perl -w

use strict;

use indexgame;
use save;

sub game_exists {
    my ($dbh, $id) = @_;

    $dbh->selectrow_array("select count(*) from game where id=?",
                          {},
                          $id);
}

sub get_game_content {
    my ($dbh, $id, $write_id) = @_;

    my ($actual_write_id, $content) =
        $dbh->selectrow_array("select write_id, commands from game where id=?",
                              {},
                              $id);

    if (defined $write_id) {
        if ($write_id ne $actual_write_id) {
            die "Invalid write_id $write_id"
        }
    } else {
        $content =~ s/email(?!-)\s*\S+/email redacted/g;
    }

    return $content;
}

sub get_game_commands {
    split /\n/, get_game_content @_;    
}

sub get_game_players {
    my ($dbh, $id) = @_;

    my ($rows) =
        $dbh->selectall_arrayref("select faction, player, email, displayname from email inner join game_role on game_role.email=email.address inner join player on player.username=email.player where game=? and faction != 'admin'",
                                 {},
                                 $id);

    my %players = ();
    for (@{$rows}) {
        $players{$_->[0]} = { username => $_->[1],
                              displayname => $_->[3],
                              email => $_->[2] };
    }

    \%players;
}

sub begin_game_transaction {
    my ($dbh, $id) = @_;
    
    $dbh->do("begin");
    $dbh->do("select * from game where id=? for update",
             {},
             $id);
}

sub finish_game_transaction {
    my ($dbh) = @_;
    
    $dbh->do("commit");
}

1;

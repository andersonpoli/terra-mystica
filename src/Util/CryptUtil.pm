use strict;

package Util::CryptUtil;
use Exporter::Easy (EXPORT => [ 'encrypt_validation_token',
                                'read_urandom_string_base64',
                                'decrypt_validation_token' ]);

use Crypt::CBC;
use Crypt::Eksblowfish::Bcrypt qw(en_base64 de_base64);
use Digest::SHA1 qw(sha1_base64);

sub encrypt_validation_token {
    my ($secret, @data) = @_;
    my $data = join "\t", @data;
    my $token;

    my $csum = sha1_base64 $data;
    $data .= "\t$csum";

    do {
        my $iv = Crypt::CBC->random_bytes(8);
        my $cipher = Crypt::CBC->new(-key => $secret,
                                     -iv => $iv,
                                     -blocksize => 8,
                                     -header => 'randomiv',
                                     -cipher => 'Blowfish');
        $token = en_base64 $cipher->encrypt($data);
        # Continue until the URL ends in a non-special character, to
        # reduce the chances of the link being mis-interpreted by email
        # clients.
    } while ($token !~ /[A-Za-z0-9]$/);

    $token;
}

sub decrypt_validation_token {
    my ($secret, $token) = @_;

    my $cipher = Crypt::CBC->new(-key => $secret,
                                 -blocksize => 8,
                                 -header => 'randomiv',
                                 -cipher => 'Blowfish');
    my $data = $cipher->decrypt(de_base64 $token);
    my @data = split /\t/, $data;

    my $token_csum = pop @data;
    my $expect_csum = sha1_base64 join "\t", @data;

    if ($token_csum ne $expect_csum) {
        die "Checksum mismatch: $expect_csum $token_csum\n";
    }

    (@data, $token_csum);
}

sub read_urandom_string_base64 {
    my $chars = shift;

    open my $f, "</dev/urandom";
    my $data = '';

    read $f, $data, $chars;

    close $f;

    substr en_base64($data), 0, $chars;
}

1;

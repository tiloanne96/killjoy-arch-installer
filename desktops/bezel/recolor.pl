#!/usr/bin/perl
# recolor.pl <mapa> <archivo>...
# Reemplaza colores en los archivos según palette.map (el formato se explica allí).
use strict;
use warnings;

my $mapfile = shift @ARGV or die "uso: recolor.pl <mapa> <archivo>...\n";

my ( %hex, @text );
open my $map, '<', $mapfile or die "no puedo abrir $mapfile: $!\n";
while ( my $line = <$map> ) {
    $line =~ s/^\s*#.*$//;       # línea de comentario
    $line =~ s/\s+#.*$//;        # comentario al final
    $line =~ s/^\s+|\s+$//g;
    next if $line eq '';

    if ( $line =~ /^hex\s+([0-9a-fA-F]{6})\s+([0-9a-fA-F]{6})$/ ) {
        my $from = lc $1;
        die "$mapfile:$.: color duplicado $from\n" if exists $hex{$from};
        $hex{$from} = lc $2;
    }
    elsif ( $line =~ /^text\s+(.+?)\s+=>\s+(.+)$/ ) {
        push @text, [ $1, $2 ];
    }
    else {
        die "$mapfile:$.: línea no válida: $line\n";
    }
}
close $map;

my $alt = join '|', map { quotemeta } sort keys %hex;

# #rrggbb, #aarrggbb y #rrggbbaa (el alfa, si existe, se conserva)
my $hash_color = qr/#([0-9a-f]{2})?($alt)([0-9a-f]{2})?(?![0-9a-f])/i;
# rgb(rrggbb) y rgba(rrggbbaa), formato de Hyprland
my $fn_color = qr/(rgba?\()($alt)([0-9a-f]{2})?(\))/i;

my ( $files, $replacements ) = ( 0, 0 );

for my $file (@ARGV) {
    open my $in, '<:raw', $file or die "no puedo leer $file: $!\n";
    my $src = do { local $/; <$in> };
    close $in;

    my $out = $src;
    my $n   = 0;

    for my $pair (@text) {
        my ( $from, $to ) = @$pair;
        $n += ( $out =~ s/\Q$from\E/$to/g );
    }
    $n += ( $out =~ s{$hash_color}{'#' . ( $1 // '' ) . $hex{ lc $2 } . ( $3 // '' )}ge );
    $n += ( $out =~ s{$fn_color}{$1 . $hex{ lc $2 } . ( $3 // '' ) . $4}ge );

    next if $out eq $src;

    open my $o, '>:raw', $file or die "no puedo escribir $file: $!\n";
    print {$o} $out;
    close $o;

    $files++;
    $replacements += $n;
}

print "recolor: $replacements reemplazos en $files archivos\n";

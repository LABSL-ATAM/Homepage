#!/usr/bin/perl
######################################################################
# Blog en un rato...
#        
#        
#        DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE 
#                    Version 2, December 2004 
#
# Copyright (C) 2016 MarxBro by LABSL-ATAM <marxbro@gmx.com> 
#
# Everyone is permitted to copy and distribute verbatim or modified 
# copies of this license document, and changing it is allowed as long 
# as the name is changed. 
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE 
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION 
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#
######################################################################
use strict;
use POSIX                   q/strftime/;
use Getopt::Std;
use Pod::Usage;
use autodie;
use feature                 qw/say/;
use File::Slurp             qw/read_file write_file/;
use Text::Markdown          qw/markdown/;
use File::Find::Rule;
use List::MoreUtils         qw/uniq/;

use Text::Format;
use XML::Entities;

use HTML::Entities;
%HTML::Entities::char2entity = %{
    XML::Entities::Data::char2entity('all');
};
=pod

=encoding utf8

=head1 SYNOPSIS

Script para bloggear como un enfermo.

=cut

my $t_banana = strftime ("%d_%B_%Y_%H_%M_%S",localtime(time()));
my $t_manzan = mes_bien_pese_a_locales(strftime ("%d-%B-%Y %H:%M",localtime(time())));

=pod

=head2 Forma de uso:

=over

=item d | h     Debug. Ayuda.

=item b         Build (hacer tutti).

=back

=cut

my %opts = ();
my $debug = 0;

getopts('dhb',\%opts);
$debug++ if $opts{d};

# Configs
my $dir_build = "build" . "__" . $t_banana;
my $dir_src     = "./src";
my $dir_dwns    = "dwns";
my %linky       = ();



#Favicon: Previene el error 404
my $favico_link_para_header = '<link rel="shortcut icon" href="favicon.ico"/>';

# C O M E N T A R I O S -> disqus.
my $comments_allow = 0; # Cambiar variables en la funcion embed_comments();

# S E O ( o algo asi )
my $blog_title = 'Laboratorio de Software Libre - ATAM';
my $blog_url = 'https://labsl.multimediales.com.ar';
my @keywords_fixed = ( qw /software libre ATAM UNA tecnologia linux perl git/ );
my $blog_autores = '"LABSL - ATAM"';
my $blog_desc = '"Blog Institucional del Laboratorio de Software Libre del ATAM - UNA."';
my $header_lab = '<header class="container">' . "Laboratorio de Software Libre del ATAM/UNA" . '</header>';

# Htaccess
my $apache_target= 1; # poner en 0 si el servidor en nginx u otro.
my $htaccess = <<EOF
# Fijarse que el directorio desde donde se sirve el contenido tenga:
# AllowOverride All, o nada de esto va a andar.
Options -Indexes -FollowSymLinks

# compresion 
<ifModule mod_deflate.c>
  AddOutputFilterByType DEFLATE text/plain
  AddOutputFilterByType DEFLATE text/html
  AddOutputFilterByType DEFLATE text/xml
  AddOutputFilterByType DEFLATE text/css
  AddOutputFilterByType DEFLATE application/xml
  AddOutputFilterByType DEFLATE application/xhtml+xml
  AddOutputFilterByType DEFLATE application/rss+xml
  AddOutputFilterByType DEFLATE application/javascript
  AddOutputFilterByType DEFLATE application/x-javascript
</ifModule>

# cachetear
<ifModule mod_expires.c>
  ExpiresActive On
  ExpiresByType image/gif "access plus 1 months"
  ExpiresByType image/jpg "access plus 1 months"
  ExpiresByType image/jpeg "access plus 1 months"
  ExpiresByType image/png "access plus 1 months"
  ExpiresByType image/vnd.microsoft.icon "access plus 1 months"
  ExpiresByType image/x-icon "access plus 1 months"
  ExpiresByType image/ico "access plus 1 months"
  ExpiresByType application/javascript "now plus 1 months"
  ExpiresByType application/x-javascript "now plus 1 months"
  ExpiresByType text/javascript "now plus 1 months"
  ExpiresByType text/css "now plus 1 months"
  ExpiresDefault "access plus 1 days"
</ifModule>

EOF
;

# Un pie al final de cada página
my $pie_html    = '<span>' . 'Última modificación: ' . 
                    $t_manzan . ' by <strong>'. $blog_autores .'</strong>.' . '</span>';

my $exitos = "Todo anduvo joya; en la carpeta " . $dir_build . " esta el blog.";

######################################################################
#                                                               Main
######################################################################
if ( $opts{h} ) {
    ayudas();
    exit 0;
} else {
    if ( $opts{b} ) {
        unless ( -d $dir_build ) {
            mkdir $dir_build;
            my $dir_b_css = $dir_build . '/css'; 
            my $dir_data_css = $dir_build . '/data'; 
            mkdir $dir_b_css;
            mkdir $dir_data_css;
        }
        build();
        say $exitos and exit 0;
    }
    else {
        ayudas() and die;
    }
}

######################################################################
#                                                           Funciones
######################################################################
sub ayudas {
    pod2usage(-verbose=>3);
}
# Funcion principal a.k.a. MAIN
sub build {
    my @pages   =   get_stuff($dir_src, '*.md'); 
    my @css     =   get_stuff($dir_src, '*.css');
    # Imagenes y cosas para linkear van a la carpeta data, 
    # hacer el link relativo: /data/img.png, etc.
    my @stuffs  =   get_stuff($dir_src, 'stuff');

    # Favicon: sin no existe, a fumarse el 404.
    if (-e './src/favicon.ico'){
        my $copy_favicon = 'cp src/favicon.ico ' . $dir_build . '/'. 'favicon.ico';
        `$copy_favicon`;
    }

    # Downloads
    my $src_dwns = $dir_src . '/' . $dir_dwns;
    if (-d $src_dwns){
        my $cm_dwns = 'cp -r ' . $src_dwns . ' ' . $dir_build . '/dwns';
        `$cm_dwns`;
    }
    

    foreach my $st (@stuffs){
        my ($sty)       =   $st         =~ m/[\/]([^\/]+)$/;
        my $final_st    =   $dir_build . '/data/' . $sty;
        my $cm = 'cp ' . $st . ' '. $final_st;
        `$cm`;
    }

    my $css_header_links = '';
    foreach my $css_src (@css){
        my $wd = read_file($css_src);
        my ($nombre_limpio) = $css_src =~ m/[\/]([^\/]+)$/;
        my $nombre_css_final = $dir_build . '/css/' . $nombre_limpio;
        my $nombre_css_final_l = 'css/' . $nombre_limpio;
        write_file($nombre_css_final,$wd);
        #write_file($nombre_css_final,optimize($wd, 1));

        #armar links
        my $link_final_css = '<link rel="stylesheet" type="text/css" href="' . 
                                $nombre_css_final_l . '">';
        $css_header_links .= $link_final_css . "\n";
    }
    my $header_with_css = make_header ($css_header_links);
    
    my @Indexes = ();
    foreach my $page (@pages){
        my $shit = read_file($page);
        #my $dinamic_keys = get_keywords($shit); # no tenemos uso tdv
        my @ii_ = stat($page);
        my $ultima_modificacion = $ii_[9];
        my $contenido = $header_with_css;
        $contenido .= '<body>' . "\n";
        $contenido .= $header_lab . "\n";
        $contenido .= '<main class="container">' . "\n";
        $contenido .= markdown($shit) . "\n";
        if ($comments_allow){
            my $comments = embed_comments();
            $contenido .= $comments;
        }
        $contenido .= '<div><a href="index.html">Volver</a></div>';
        $contenido .= pie();
        my ($titulo_page,$titulo_index) = make_title($shit);
        my $nombre_archivo_final = $dir_build . '/' . $titulo_page . '.html';
        my $nombre_archivo_final_l = $titulo_page . '.html';
        $linky{$nombre_archivo_final_l} = $titulo_index . 'spliteo' . $ultima_modificacion;
        say $contenido if $debug;
        write_file( $nombre_archivo_final , optimize($contenido , 0));
    }


# I N D E X
    my $indexin = $header_with_css;
    $indexin .= '<body>';
    $indexin .= '<header class="container">'.index_datas().'</header>';
    $indexin .= '<main class="container">' . "\n";
    #$indexin .= index_datas();
    $indexin .= do_index();
    my $indexin_file_nombre = $dir_build . '/index.html';
    #write_file( $indexin_file_nombre , optimize($indexin,0) );
    write_file( $indexin_file_nombre , $indexin );

# H T A CCESS
    do_htaccess();

# R S S
    my $rss_file_out = $dir_build . '/rss';
    my $rss_to_write_file = do_rss();
    write_file( $rss_file_out , $rss_to_write_file);

}

sub do_SEOand_shut_up{
    my $meta_desc = '<meta name="description" content=' . $blog_desc . '>';
    my $meta_author = '<meta name="author" content=' . $blog_autores . '>';
    my $meta_key = '<meta name="keywords" content=';
    my $string_keywords = '"' . join(', ',@keywords_fixed) . '"' . '>';
    my $final_string_seo = $meta_author . $meta_desc . $meta_key . $string_keywords;
    return $final_string_seo;
}

sub get_keywords {
    # a keywords is anything longer than 5 caracters. 
    my $inputo = $_[0];
    my @words = split(/\s+/,$inputo);
    my @words_b = map { $_ =~ /\W+(\w+)\W+/gi ? length ($1) >= 5 ?  $1 : () : () } uniq(@words);
    my $cdeJu = join (', ',@words_b);
    return $cdeJu;
}

sub do_index {
    my $ind = '<h2>Entradas:</h2>';
    $ind .= '<table>';
    foreach my $n_html_page (sort(keys(%linky))){
        my ($l,$modif) = split(/spliteo/, $linky{$n_html_page});
        my $modifiz = mes_bien_pese_a_locales(strftime ("%d - %B - %Y %H:%M",localtime( $modif )));
        my $lllll    = '<tr><td>' .
            '<a href="' . $n_html_page . '" >' . $l . 
            '</a>' . '</td><td>' . $modifiz . '</td>' .
            '</tr>';
        $ind        .= $lllll . "\n";
    }
    $ind .= '</table>';
    $ind .= pie();
    return $ind;
}

sub pie{
   my $fin = '</main>';
   $fin .= '<footer class="container">'.$pie_html . '</footer>';
   $fin .= '</body></html>';
   return $fin;
}

sub make_header {
    my $in = $_[0];
    my $fucking_utf = '<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>' . "\n";
    my $fuente = '<link href="https://fonts.googleapis.com/css?family=Droid+Sans+Mono" rel="stylesheet"/>' . "\n";
    my $fucking_seo = do_SEOand_shut_up();
    my $favico_data = '<link rel="apple-touch-icon" sizes="57x57" href="/data/apple-icon-57x57.png">
        <link rel="apple-touch-icon" sizes="60x60" href="/data/apple-icon-60x60.png">
        <link rel="apple-touch-icon" sizes="72x72" href="/data/apple-icon-72x72.png">
        <link rel="apple-touch-icon" sizes="76x76" href="/data/apple-icon-76x76.png">
        <link rel="apple-touch-icon" sizes="114x114" href="/data/apple-icon-114x114.png">
        <link rel="apple-touch-icon" sizes="120x120" href="/data/apple-icon-120x120.png">
        <link rel="apple-touch-icon" sizes="144x144" href="/data/apple-icon-144x144.png">
        <link rel="apple-touch-icon" sizes="152x152" href="/data/apple-icon-152x152.png">
        <link rel="apple-touch-icon" sizes="180x180" href="/data/apple-icon-180x180.png">
        <link rel="icon" type="image/png" sizes="192x192"  href="/data/android-icon-192x192.png">
        <link rel="icon" type="image/png" sizes="32x32" href="/data/favicon-32x32.png">
        <link rel="icon" type="image/png" sizes="96x96" href="/data/favicon-96x96.png">
        <link rel="icon" type="image/png" sizes="16x16" href="/data/favicon-16x16.png">
        <link rel="manifest" href="/data/manifest.json">
        <meta name="msapplication-TileColor" content="#ffffff">
        <meta name="msapplication-TileImage" content="/ms-icon-144x144.png">
        <meta name="theme-color" content="#ffffff">';
    my $rss_link_header = '<link rel="alternate" type="application/rss+xml" title="RSS 2.0" href="' . $blog_url . '/rss">';
    my $H = '<!doctype html><head>' . $fucking_seo . $favico_data . $rss_link_header ."\n" . $in . "\n" . $fucking_utf . $fuente . '</head>';
    #my $H = '<!doctype html><head>' . $fucking_seo . $favico_link_para_header . "\n" . $in . "\n" . $fucking_utf . $fuente . '</head>';
    return $H;    
}


sub make_title {
    my $o = $_[0];
    my @dd = split ( /\n/, $o );
    my $c = $dd[0];
    $c =~ s/^#//g;
    $c =~ s/ //;
    my $d = $c;
    $c =~ s/ /_/g;
    $c =~ s/á/a/gi;
    $c =~ s/é/e/gi;
    $c =~ s/í/i/gi;
    $c =~ s/ó/o/gi;
    $c =~ s/ú/u/gi;
    $c =~ s/ñ/ñ/gi;
    $c =~ s/!/sep/gi;
    return ($c, $d);
}




sub get_stuff {
    my $pp = $_[0];
    my $stuff = $_[1];
    my @ff = ();
    if ($stuff eq 'stuff'){
        @ff = File::Find::Rule   -> file ()
                                    -> name ('*.png', '*.jpeg', '*.jpg', '*.gif', '*.json', '*.xml')
                                    -> in   ($pp);
    } else {
        @ff = File::Find::Rule   -> file ()
                                    -> name ($stuff)
                                    -> in   ($pp);
    }
    return @ff;
}


sub index_datas {
    my $md = '';
    while (<DATA>){
        $md .= $_;
    }
    my $coso = markdown($md);
    return $coso;
}

sub optimize {
    my $inputy = $_[0];
    my $espacios = $_[1];
    $inputy =~ s/\n+|\t+//g;
    if ($espacios) {
        $inputy =~ s/\s+//g;
    }
    return $inputy;
    }


sub embed_comments {
    my $disqus_page_url         = '"https://URL.com"' ;
    my $disqus_identifier       = '"NAME"';
    my $disqus_forum_shortname  = 127361823;

    my $comments = '
<div id="disqus_thread"></div><script>
    var disqus_config = function () {
        this.page.url = PAGE_URL;
        this.page.identifier = PAGE_IDENTIFIER;
    };
    (function() { 
        var d = document, s = d.createElement("script");
        s.src = "https://EXAMPLE.disqus.com/embed.js"; 
        s.setAttribute("data-timestamp", +new Date());
        (d.head || d.body).appendChild(s);
    })();
</script>
<noscript>JavaScript es necesario para ver los <a href="https://disqus.com/?ref_noscript" rel="nofollow">comentarios.</a></noscript>
';


    $comments =~ s/PAGE_URL/$disqus_page_url/;             #// Replace PAGE_URL with your page's canonical URL variable
    $comments =~ s/PAGE_IDENTIFIER/$disqus_identifier/;    #// Replace PAGE_IDENTIFIER with your page's unique identifier variable
    $comments =~ s/EXAMPLE/$disqus_forum_shortname/;       #// IMPORTANT: Replace EXAMPLE with your forum shortname!
    return $comments;
}

sub do_htaccess {
    my $ht_nn = $dir_build . '/.htaccess' ;
    write_file($ht_nn,$htaccess);
    chmod 0755, $ht_nn;
}

sub mes_bien_pese_a_locales {
    my $mes = shift;
    $mes =~ s/January/Enero/g;
    $mes =~ s/February/Febrero/g;
    $mes =~ s/March/Marzo/g;
    $mes =~ s/April/Abril/g;
    $mes =~ s/May/Mayo/g;
    $mes =~ s/June/Junio/g;
    $mes =~ s/July/Julio/g;
    $mes =~ s/August/Agosto/g;
    $mes =~ s/September/Septiembre/g;
    $mes =~ s/October/Octubre/g;
    $mes =~ s/November/Noviembre/g;
    $mes =~ s/December/Diciembre/g;
    return $mes;
}

sub do_rss {
    my $rss_header = '<?xml version="1.0" encoding="UTF-8" ?><rss version="2.0"><channel>' .
        '<title>'.  xen($blog_title) .  '</title><link>'.  xen($blog_url) .  '</link><description>' .  
        xen($blog_desc) . '</description>';

    my $feeds = $rss_header;
    foreach my $n_html_page (reverse(sort { $linky{$a} <=> $linky{$b} } keys %linky)){
        my ($l,$modif) = split(/spliteo/, $linky{$n_html_page});
        my $modifiz = mes_bien_pese_a_locales(strftime ("%a, %d %m %Y %T %Z",localtime( $modif )));
        say $modifiz if $debug;
        $feeds .= '<item><title>' . xen($l). '</title><link>'. xen($n_html_page) . '</link><description>' .
            xen($l) . '</description><pubDate>' . xen($modifiz) . '</pubDate></item>';
    }
    $feeds .= '</channel></rss>';
    say $feeds if $debug;
    return $feeds;
}

sub xen {
    my $in = shift;
    #my $out = XML::Entities::numify('all',encode_entities($in));
    my $out = XML::Entities::numify('all', encode_entities($in, '"<>/&%?:'));
    return $out;
}
######################################################################
#                                                       P O D  Z O N E
######################################################################
=pod

=head1 Autor y Licencia.

Programado por B<Marxbro> aka B<Gstv>, distribuir preferentemente
bajo la licencia WTFPL: I<Do What the Fuck You Want To Public License>.

Zaijian.

=cut

__DATA__

# Laboratorio de Software Libre del ATAM - UNA.

Esta es la página oficial del LABSL del ATAM/UNA.

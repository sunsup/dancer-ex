package inventory;
use Dancer2 ':syntax';
use Dancer2 ':script';
use Template;
use DBI;
use DBD::mysql;

set template => 'template_toolkit';
set layout => 'main';
set views => File::Spec->rel2abs('./views');
set 'username' => 'mainuser';
set 'password' => 'password';

set session => 'YAML';
#set session => 'Simple';

my $flash;
 
sub set_flash {
    my $message = shift;
    $flash = $flash.":".$message;
};
 
sub get_flash {
    my $msg = $flash;
    $flash = "";
    return $msg;
};
hook before_template_render => sub {
    my $tokens = shift;
 
    $tokens->{'css_url'} = request->base . 'css/style.css';
    $tokens->{'login_url'} = uri_for('/login');
    $tokens->{'logout_url'} = uri_for('/logout');
};
=pod
hook before => sub {
  set_flash('Started in hook before');
  #if (not session('user') && request->path !~ m{^/login}) {
  if ( !session('logged_in') )  {
   set_flash('NOT LOGGED IN');
   #template login => { path => query_parameters->get('requested_path'),err => get_flash()};
   template 'login.tt', {'err' => get_flash()};
  } else {
   set_flash('Good to Go '.session('user'));
  }
=cut
hook before => sub {
  set_flash('Started in hook before');
  if (!session('user') && request->path !~ m{^/login}) {
   set_flash('NOT LOGGED IN');
            # Pass the original path requested along to the handler:
            forward '/login', { requested_path => request->path };
   }
};
 #   } else {
 #       set_flash(session('user'));
 #       forward '/login', { requested_path => request->path };
 #   }
#};
get '/' => sub {
    #set_flash(session('user'));
    if ( not session('logged_in') ) {
        set_flash(session('You ought to know, youre not logged in'));
    }
    my $dbh = get_connection();

    eval { $dbh->prepare("SELECT * FROM foo")->execute() };
    init_db($dbh) if $@;

    my $sth = $dbh->prepare("SELECT * FROM foo");
    $sth->execute();

    my $data = $sth->fetchall_hashref('id');
    $sth->finish();

    my $timestamp = localtime();
    template index => {data => $data, timestamp => $timestamp, msg => get_flash()};
};

post '/' => sub {
   my $name = params->{name};
   my $email = params->{email};

   my $dbh = get_connection();
   
   $dbh->do("INSERT INTO foo (name, email) VALUES (" . $dbh->quote($name) . ", " . $dbh->quote($email) . ") ");

   my $sth = $dbh->prepare("SELECT * FROM foo");
   $sth->execute();

   my $data = $sth->fetchall_hashref('id');
   $sth->finish();

   my $timestamp = localtime();
   template index => {data => $data, timestamp => $timestamp,msg => get_flash()};
};
  
get '/secret' => sub { return "Top Secret Stuff here"; };
 
=pod
get '/login' => sub {
    # Display a login page; the original URL they requested is available as
    # query_parameters->get('requested_path'), so could be put in a hidden field in the form
    #template 'login', { path => query_parameters->get('requested_path'),msg =>get_flash() };
    template login => { path => query_parameters->get('requested_path'),msg => get_flash()};
};
 
post '/login' => sub {
    # Validate the username and password they supplied
    if (body_parameters->get('username') eq 'mainuser' && body_parameters->get('password') eq 'password') {
        session 'user' => body_parameters->get('username');
        session 'logged_in' => true;
        redirect body_parameters->get('path') || '/';
    } else {
   #     redirect '/login?failed=2';
        template login => { path => query_parameters->get('requested_path'),msg => get_flash()};
    }
};
=cut
any ['get', 'post'] => '/login' => sub {
    my $err;
 
    if ( request->method() eq "POST" ) {
        # process form input
        if ( body_parameters->get('username') ne setting('username') ) {
            $err = "Invalid username";
        }
        elsif ( body_parameters->get('password') ne setting('password') ) {
            $err = "Invalid password";
        }
        else {
            session 'user' => body_parameters->get('username');
            session 'logged_in' => true;
            redirect body_parameters->get('path') || '/';
            set_flash('You are logged in.');
            return redirect '/';
        }
   }
   
   template 'login.tt', { path => query_parameters->get('requested_path'),'err' => $err};
 
   # display login form
 #  template 'login.tt', {
  #     'err' => $err,
   #};
 
};

sub get_connection{
  my $service_name=uc $ENV{'DATABASE_SERVICE_NAME'};
  my $db_host=$ENV{"${service_name}_SERVICE_HOST"};
  my $db_port=$ENV{"${service_name}_SERVICE_PORT"};
  my $dbh=DBI->connect("DBI:mysql:database=$ENV{'MYSQL_DATABASE'};host=$db_host;port=$db_port",$ENV{'MYSQL_USER'},$ENV{'MYSQL_PASSWORD'}, { RaiseError => 1 } ) or die ("Couldn't connect to database: " . DBI->errstr );
  return $dbh;
}

sub init_db{

  my $dbh = $_[0];

  eval { $dbh->do("DROP TABLE foo") };

  $dbh->do("CREATE TABLE foo (id INTEGER not null auto_increment, name VARCHAR(20), email VARCHAR(30), PRIMARY KEY(id))");
  $dbh->do("INSERT INTO foo (name, email) VALUES (" . $dbh->quote("Eric") . ", " . $dbh->quote("eric\@example.com") . ")");
};


get '/user/:id' => sub {
    my $timestamp = localtime();
    my $dbh = get_connection();

    my $sth = $dbh->prepare("SELECT * FROM foo WHERE id=?") or die "Could not prepare statement: " . $dbh->errstr;
    $sth->execute(params->{id});

    my $data = $sth->fetchall_hashref('id');
    $sth->finish();

    template user => {timestamp => $timestamp, data => $data};
};
get '/health' => sub {
  my $dbh  = get_connection();
  my $ping = $dbh->ping();

  if ($ping and $ping == 0) {
    # This is the 'true but zero' case, meaning that ping() is not implemented for this DB type.
    # See: http://search.cpan.org/~timb/DBI-1.636/DBI.pm#ping
    return "WARNING: Database health uncertain; this database type does not support ping checks.";
  }
  elsif (not $ping) {
    status 'error';
    return "ERROR: Database did not respond to ping.";
  }
  return "SUCCESS: Database connection appears healthy.";
}; 
get '/logout' => sub {
   app->destroy_session;
   set_flash('You are logged out.');
   redirect '/';
};

true;

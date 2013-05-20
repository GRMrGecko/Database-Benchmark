#!/usr/bin/perl

use DBI;
use Text::CSV;
use Data::Dumper;
use Lingua::EN::Nums2Words;
use Time::HiRes qw/ time /;
use POSIX;

my $csv = Text::CSV->new({binary => 1}) or die "Cannot use CSV: ".Text::CSV->error_diag();

my $dbh = DBI->connect("DBI:mysql:database=test;host=127.0.0.1","root","password");

my $start = time();

my $columnStructure = "id INTEGER";
my $rowCount = 0;
my $columnCount = 0;
my $columnTitles = undef;
open(my $fh, "<".$ENV{"HOME"}."/Desktop/data.csv");
my $sth = $dbh->prepare("START TRANSACTION;");
$sth->execute();
while (my $row = $csv->getline($fh)) {
	$rowCount++;
	if ($rowCount==1) {
		$columnCount = scalar(@$row);
		$columnTitles = $row;
		for (my $i=0; $i<scalar(@$row); $i++) {
			$columnStructure .= ",".$row->[$i]." TEXT";
		}
		my $sth = $dbh->prepare("CREATE TABLE posts(".$columnStructure.") ENGINE = MYISAM;");
		$sth->execute();
		next;
	}
	my @data = ();
	push(@data,$rowCount-1);
	my $columns = "id";
	my $values = "?";
	for (my $i=0; $i<$columnCount; $i++) {
		$columns .= ",".$columnTitles->[$i];
		$values .= ",?";
		push(@data,$row->[$i]);
	}
	my $sth = $dbh->prepare("INSERT INTO posts (".$columns.")VALUES(".$values.");");
	$sth->execute(@data);
}
my $sth = $dbh->prepare("COMMIT;");
$sth->execute();
$csv->eof or $csv->error_diag();
close($fh);

my $runTime = sprintf("%.5f", time()-$start);
print "Insert ".$rowCount." rows: ".$runTime."\n";

my $start = time();
my $sth = $dbh->prepare("ALTER TABLE posts ADD FULLTEXT(data);");
$sth->execute();

my $runTime = sprintf("%.5f", time()-$start);
print "Create index: ".$runTime."\n";

my $start = time();
my $sth = $dbh->prepare("SELECT * FROM posts WHERE MATCH(data) AGAINST(?) LIMIT 100;");
$sth->execute("feet");
while (my $row = $sth->fetchrow_hashref) {
	#Do nothing
}
my $runTime = sprintf("%.5f", time()-$start);
print "Search Index: ".$runTime."\n";

my $start = time();
my $sth = $dbh->prepare("SELECT * FROM posts WHERE data LIKE ? LIMIT 100;");
$sth->execute("\%feet\%");
while (my $row = $sth->fetchrow_hashref) {
	#Do nothing
}
my $runTime = sprintf("%.5f", time()-$start);
print "Find by string contains: ".$runTime."\n";

my $start = time();
my $sth = $dbh->prepare("SELECT * FROM posts WHERE id=584;");
$sth->execute();
while (my $row = $sth->fetchrow_hashref) {
	#Do nothing
}
my $runTime = sprintf("%.5f", time()-$start);
print "Find by id: ".$runTime."\n";

my $sth = $dbh->prepare("DROP TABLE posts;");
$sth->execute();

my $sth = $dbh->prepare("CREATE TABLE t1(a INTEGER, b INTEGER, c VARCHAR(100)) ENGINE = MYISAM;");
$sth->execute();

my $start = time();
for (my $i=0; $i<1000; $i++) {
	my $number = $i*135;
	my $sth = $dbh->prepare("INSERT INTO t1 (a,b,c)VALUES(?,?,?);");
	$sth->execute($i,$number,num2word($number));
}
my $runTime = sprintf("%.5f", time()-$start);
print "1000 INSERTs: ".$runTime."\n";

my $sth = $dbh->prepare("CREATE TABLE t2(a INTEGER, b INTEGER, c VARCHAR(100)) ENGINE = MYISAM;");
$sth->execute();

my $start = time();
my $sth = $dbh->prepare("START TRANSACTION;");
$sth->execute();
for (my $i=0; $i<25000; $i++) {
	my $number = $i*135;
	my $sth = $dbh->prepare("INSERT INTO t2 (a,b,c)VALUES(?,?,?);");
	$sth->execute($i,$number,num2word($number));
}
my $sth = $dbh->prepare("COMMIT;");
$sth->execute();
my $runTime = sprintf("%.5f", time()-$start);
print "25000 INSERTs in a transaction: ".$runTime."\n";

my $sth = $dbh->prepare("CREATE TABLE t3(a INTEGER, b INTEGER, c VARCHAR(100)) ENGINE = MYISAM;");
$sth->execute();
my $sth = $dbh->prepare("CREATE INDEX i3 ON t3(c);");
$sth->execute();

my $start = time();
my $sth = $dbh->prepare("START TRANSACTION;");
$sth->execute();
for (my $i=0; $i<25000; $i++) {
	my $number = $i*135;
	my $sth = $dbh->prepare("INSERT INTO t3 (a,b,c)VALUES(?,?,?);");
	$sth->execute($i,$number,num2word($number));
}
my $sth = $dbh->prepare("COMMIT;");
$sth->execute();
my $runTime = sprintf("%.5f", time()-$start);
print "25000 INSERTs into an indexed table: ".$runTime."\n";

my $start = time();
for (my $i=0; $i<100; $i++) {
	my $number = $i*100;
	my $sth = $dbh->prepare("SELECT count(*), avg(b) FROM t2 WHERE b>=? AND b<?;");
	$sth->execute($number,$number+1000);
	my $row = $sth->fetchrow_hashref;
}
my $runTime = sprintf("%.5f", time()-$start);
print "100 SELECTs without an index: ".$runTime."\n";

my $start = time();
for (my $i=0; $i<100; $i++) {
	my $number = $i;
	my $sth = $dbh->prepare("SELECT count(*), avg(b) FROM t2 WHERE c LIKE ?;");
	$sth->execute("%".num2word($number)."%");
	my $row = $sth->fetchrow_hashref;
}
my $runTime = sprintf("%.5f", time()-$start);
print "100 SELECTs on a string comparison: ".$runTime."\n";

my $start = time();
my $sth = $dbh->prepare("CREATE INDEX i2a ON t2(a);");
$sth->execute();
my $sth = $dbh->prepare("CREATE INDEX i2b ON t2(b);");
$sth->execute();
my $runTime = sprintf("%.5f", time()-$start);
print "Creating an index: ".$runTime."\n";

my $start = time();
for (my $i=0; $i<5000; $i++) {
	my $number = $i*100;
	my $sth = $dbh->prepare("SELECT count(*), avg(b) FROM t2 WHERE b>=? AND b<?;");
	$sth->execute($number,$number+1000);
	my $row = $sth->fetchrow_hashref;
}
my $runTime = sprintf("%.5f", time()-$start);
print "5000 SELECTs with an index: ".$runTime."\n";

my $start = time();
my $sth = $dbh->prepare("START TRANSACTION;");
$sth->execute();
for (my $i=0; $i<1000; $i++) {
	my $number = $i*10;
	my $sth = $dbh->prepare("UPDATE t1 SET b=b*2 WHERE a>=? AND a<?;");
	$sth->execute($number,$number+10);
}
my $sth = $dbh->prepare("COMMIT;");
$sth->execute();
my $runTime = sprintf("%.5f", time()-$start);
print "1000 UPDATEs without an index: ".$runTime."\n";

my $start = time();
my $sth = $dbh->prepare("START TRANSACTION;");
$sth->execute();
for (my $i=0; $i<25000; $i++) {
	my $number = $i*123;
	my $sth = $dbh->prepare("UPDATE t2 SET b=? WHERE a=?;");
	$sth->execute($number,$i);
}
my $sth = $dbh->prepare("COMMIT;");
$sth->execute();
my $runTime = sprintf("%.5f", time()-$start);
print "25000 UPDATEs with an index: ".$runTime."\n";

my $start = time();
my $sth = $dbh->prepare("START TRANSACTION;");
$sth->execute();
for (my $i=0; $i<25000; $i++) {
	my $number = $i*123;
	my $sth = $dbh->prepare("UPDATE t2 SET c=? WHERE a=?;");
	$sth->execute(num2word($number),$i);
}
my $sth = $dbh->prepare("COMMIT;");
$sth->execute();
my $runTime = sprintf("%.5f", time()-$start);
print "25000 text UPDATEs with an index: ".$runTime."\n";

my $start = time();
my $sth = $dbh->prepare("START TRANSACTION;");
$sth->execute();
my $sth = $dbh->prepare("INSERT INTO t1 SELECT b,a,c FROM t2;");
$sth->execute();
my $sth = $dbh->prepare("INSERT INTO t2 SELECT b,a,c FROM t1;");
$sth->execute();
my $sth = $dbh->prepare("COMMIT;");
$sth->execute();
my $runTime = sprintf("%.5f", time()-$start);
print "INSERTs from a SELECT: ".$runTime."\n";

my $start = time();
my $sth = $dbh->prepare("DELETE FROM t2 WHERE c LIKE '\%fifty\%';");
$sth->execute();
my $runTime = sprintf("%.5f", time()-$start);
print "DELETE without an index: ".$runTime."\n";

my $start = time();
my $sth = $dbh->prepare("DELETE FROM t2 WHERE a>10 AND a<20000;");
$sth->execute();
my $runTime = sprintf("%.5f", time()-$start);
print "DELETE with an index: ".$runTime."\n";

my $start = time();
my $sth = $dbh->prepare("INSERT INTO t2 SELECT * FROM t1;");
$sth->execute();
my $runTime = sprintf("%.5f", time()-$start);
print "A big INSERT after a big DELETE: ".$runTime."\n";

my $start = time();
my $sth = $dbh->prepare("START TRANSACTION;");
$sth->execute();
my $sth = $dbh->prepare("DELETE FROM t1;");
$sth->execute();
for (my $i=0; $i<12000; $i++) {
	my $number = $i*165;
	my $sth = $dbh->prepare("INSERT INTO t1 (a,b,c)VALUES(?,?,?);");
	$sth->execute($i,$number,num2word($number));
}
my $sth = $dbh->prepare("COMMIT;");
$sth->execute();
my $runTime = sprintf("%.5f", time()-$start);
print "A big DELETE followed by many small INSERTs: ".$runTime."\n";

my $start = time();
my $sth = $dbh->prepare("DROP TABLE t1;");
$sth->execute();
my $sth = $dbh->prepare("DROP TABLE t2;");
$sth->execute();
my $sth = $dbh->prepare("DROP TABLE t3;");
$sth->execute();
my $runTime = sprintf("%.5f", time()-$start);
print "DROP TABLE: ".$runTime."\n";

sub hex2bin {
	my $h = shift;
	my $hlen = length($h);
	return pack("H$hlen", $h);
}
my $sth = $dbh->prepare("CREATE TABLE ips(a BLOB(16), b BLOB(16), c INTEGER) ENGINE = MYISAM;");
$sth->execute();
for (my $i=0; $i<10; $i++) {
	my $binary = hex2bin("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".$i."0");
	my $binaryEnd = hex2bin("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".$i."F");
	my $sth = $dbh->prepare("INSERT INTO ips (a,b,c)VALUES(?,?,?);");
	$sth->execute($binary,$binaryEnd,$i);
}

my $correct = 1;
for (my $i=0; $i<10; $i++) {
	my $binary = hex2bin("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".$i."5");
	my $sth = $dbh->prepare("SELECT * FROM ips WHERE a<=? AND b>?;");
	$sth->execute($binary,$binary);
	my $row = $sth->fetchrow_hashref;
	unless ($row->{'c'}==$i) {
		$correct = 0;
		print "Unable to find ".$i." ".$binary." in the database.\n";
	}
}
if ($correct) {
	print "Binary range seems to work.\n";
}
my $sth = $dbh->prepare("DELETE FROM ips;");
$sth->execute();

my $start = time();
my $sth = $dbh->prepare("START TRANSACTION;");
$sth->execute();
for (my $a=0; $a<10; $a++) {
	for (my $b=0; $b<10; $b++) {
		for (my $c=0; $c<10; $c++) {
			for (my $d=0; $d<10; $d++) {
				for (my $e=0; $e<10; $e++) {
					for (my $f=0; $f<10; $f++) {
						for (my $g=0; $g<10; $g++) {
							my $binary = hex2bin("FFFFFFFFFFFFFFFF".$a."F".$b."F".$c."F".$d."F".$e."F".$f."F".$g."FF0");
							my $binaryEnd = hex2bin("FFFFFFFFFFFFFFFF".$a."F".$b."F".$c."F".$d."F".$e."F".$f."F".$g."FFF");
							my $sth = $dbh->prepare("INSERT INTO ips (a,b)VALUES(?,?);");
							$sth->execute($binary,$binaryEnd);
						}
					}
				}
			}
		}
	}
}
my $sth = $dbh->prepare("COMMIT;");
$sth->execute();
my $runTime = sprintf("%.5f", time()-$start);
print "Insert large amount of test IP Addreses: ".$runTime."\n";

my $sth = $dbh->prepare("SELECT COUNT(*) FROM ips;");
$sth->execute();
my $result = $sth->fetchrow_hashref;
print Dumper($result);

my $start = time();
my $binary = hex2bin("FFFFFFFFFFFFFFFF5F7F8F3F9F0F6FF4");
my $sth = $dbh->prepare("SELECT * FROM ips WHERE a<=? AND b>?;");
$sth->execute($binary,$binary);
my $row = $sth->fetchrow_hashref;
print Dumper($row);
my $runTime = sprintf("%.5f", time()-$start);
print "Find one IP Address: ".$runTime."\n";

my $sth = $dbh->prepare("DROP TABLE ips;");
$sth->execute();
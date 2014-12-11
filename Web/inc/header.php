<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="dcterms.created" content="Sat, 03 May 2014 01:02:31 GMT">
    <meta name="description" content="">
    <meta name="keywords" content="">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href='http://fonts.googleapis.com/css?family=Dosis:300,500,700|Droid+Sans:400,700' rel='stylesheet' type='text/css'>
	<link type="text/css" rel="stylesheet" href="bootstrap/css/bootstrap.min.css" />
	<link type="text/css" rel="stylesheet" href="HomePageStyles.css" />
    <title>	StatMouse</title>

    <!--[if IE]>
    <script src="http://html5shim.googlecode.com/svn/trunk/html5.js"></script>
    <![endif]-->    
    <script src="bootsrap/js/bootsrap.min.js"></script>
  </head>
  <body>
  
  	<div class="navbar-header">
		<a href="index.php" id="logo"><img src="img/StatMouse Logo.png" width="48px" height="76px" /></a>
	</div>

	<div role="navigation">	
		<ul class="nav nav-pills">

			<li role="presentation" <?php if ($pageclass=="index") echo 'class="active"'; ?>><a href="index.php">
				StatMouse
			</a></li>		
						 
			<li role="presentation" <?php if ($pageclass=="champions") echo 'class="active"'; ?>><a href="champions.php">
				Champions
			</a></li>
			 
		 </ul>
	</div>
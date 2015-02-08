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
    <title>StatMouse</title>

    <!--[if IE]>
    <script src="http://html5shim.googlecode.com/svn/trunk/html5.js"></script>
    <![endif]-->    
    <script src="bootsrap/js/bootsrap.min.js"></script>
  </head>
  <body>
	<!-- Google Tag Manager -->
	<noscript><iframe src="//www.googletagmanager.com/ns.html?id=GTM-TJDJ6K" height="0" width="0" style="display:none;visibility:hidden"></iframe></noscript>
	<script>
		(function(w,d,s,l,i){w[l]=w[l]||[];
		w[l].push({'gtm.start':new Date().getTime(),event:'gtm.js'});
		var f=d.getElementsByTagName(s)[0],j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;
		j.src='//www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
		})(window,document,'script','dataLayer','GTM-TJDJ6K');
	</script>
	<!-- End Google Tag Manager -->
  
  	<div class="navbar-header">
		<a href="index.php" id="logo"><img src="img/StatMouse Logo.png" width="48px" height="76px"/></a>
	</div>

	<div role="navigation">	
		<ul class="nav nav-pills">

			<li role="presentation" <?php if ($pageclass=="index") echo 'class="active"'; ?>><a href="index.php">
				StatMouse
			</a></li>		
						 
			<li role="presentation" <?php if ($pageclass=="champions") echo 'class="active"'; ?>><a href="champions.php">
				Champions
			</a></li>
			
			
			<form class="navbar-form navbar-left" role="search" method="get" action="search.php">
				<div class="form-group">
					<input type="text" name="go" class="form-control" placeholder="Champion Name">
				</div>
				<button type="submit" value="Submit" class="btn btn-default">Submit</button>
			</form>
			 
		 </ul>
	</div>
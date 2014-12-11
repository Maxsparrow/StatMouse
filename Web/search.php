<?php
include('connections.php');
include('model/champion.php');	

if(isset($_GET['go'])){
	$go = $_GET['go'];
}

if(isset($_GET['pg'])){
	$page = $_GET['pg'];
} else {
	$page = 0;
}

if(isset($_GET['numPerPage'])){
	$numPerPage = $_GET['numPerPage'];
} else {
	$numPerPage =50;
}

//Call query using search terms
$query = "SELECT DISTINCT(championName) FROM `itempower` WHERE championName LIKE :searchterm order by championName limit :numPerPage offset :offset";
$stmt = $db->prepare($query);
$stmt->bindValue(':searchterm','%'.$go.'%', PDO::PARAM_STR);
$stmt->bindValue(':numPerPage', $numPerPage, PDO::PARAM_INT);
$stmt->bindValue(':offset', $page*$numPerPage, PDO::PARAM_INT);
$stmt->execute();
$results = $stmt->fetchAll();

//If there is only one result, redirect to that page
if(count($results)==1) {
	$champion = new Champion($results[0]['championName']);	
	/* Redirect browser */
	header("Location: champion.php?champion=".htmlentities($champion->name));
	exit;
}
?>


<?php 
$pageclass="champions";
include('inc/header.php');
?>	
	<div class="container">
		<h2>Champions</h2>
		
		<?php
		//Loop through query results and return all the champions
			$rowcounter=0;
			foreach($results as $row) {
				$champion = new Champion($row['championName']);				
				$championurl = "<a href='".$champion->GetChampionPageUrl()."' style='color: black;'>";
	    			echo "<div style='display:inline-block;max-width:90px;margin:6px;'>".$championurl;
	    			echo "<figure><img style='max-width:100%;' src='".$champion->GetImagePath()."' /><figcaption style='font-size:12px;text-align:center;'>".$row['championName']."</figcaption></figure>";
	    			echo "</a></div>";
	    			$rowcounter+=1;
    			}
		?> 
		
    		<?php
		//Pagination CBJ 12.10.14
		echo "<nav><ul class='pager'>";
		
			if ($page!=0) echo "<li class='previous'><a href='search.php?go=".htmlentities($go, ENT_QUOTES)."&pg=".($page-1)."' style='color: black;'> Previous Page </a></li>";
			if (count($results)>=$numPerPage) echo "<li class='next'><a href='search.php?go=".htmlentities($go, ENT_QUOTES)."&pg=".($page+1)."' style='color: black;'> Next Page </a></li>";
			
		echo "</ul></nav>";
		?>
	</div>
		
	<?php 
	$db = null;
	?>
		
<?php include('inc/footer.php'); ?>
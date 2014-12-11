<?php 
$pageclass="champions";
include('inc/header.php');
include('model/champion.php');
?>
	
	<?php
	include('connections.php');
	
	$champion = $_GET['champion'];
	echo $champion;
	if(isset($_GET['pg'])){
		$page = $_GET['pg'];
	} else {
		$page = 0;
	}

	if(isset($_GET['numPerPage'])){
		$numPerPage = $_GET['numPerPage'];
	} else {
		$numPerPage = 13;
	}
	
	$query = "SELECT * FROM itempower where championName = :champion order by itemPower desc limit :numPerPage offset :offset";
	?>
	
	<div class="container">
		<?php 
		$champion = new Champion($champion); 
		echo "<h2><img style='width:90px;' src='".$champion->GetImagePath()."' /> ";
		echo $champion->name;
		echo "</h2>";
		?>
		
		<table class="table-bordered">
		<thead><tr><th>Item Name</th><th>Popularity</th><th>Item Power</th></tr></thead>
		<tbody>
		
		<?php
			$stmt = $db->prepare($query);
			$stmt->bindValue(':champion', $champion->name, PDO::PARAM_STR);
			$stmt->bindValue(':numPerPage', $numPerPage, PDO::PARAM_INT);
			$stmt->bindValue(':offset', $page*$numPerPage, PDO::PARAM_INT);
			$stmt->execute();
			$results = $stmt->fetchAll();
			foreach($results as $row) {
	    			echo "<tr><td><img style='height: 50%;' src='/img/item/".$row['itemId'].".png' /> ".$row['itemName']."</td>";
	    			echo "<td style='text-align:center;'>".$row['popularityPerc']."%</td>";
	    			echo "<td style='text-align:center;'>".$row['itemPower']."</td></tr>";
    		}
		?>
		
		</tbody>
		</table>	

    	<?php
		//Pagination CBJ 12.10.14
			echo "<nav><ul class='pager'>";
			
				if ($page!=0) echo "<li class='previous'><a href='champion.php?champion=".htmlentities($champion->name, ENT_QUOTES)."&pg=".($page-1)."' style='color: black;'> Previous Page </a></li>";			
				if (count($results)>=$numPerPage) echo "<li class='next'><a href='champion.php?champion=".htmlentities($champion->name, ENT_QUOTES)."&pg=".($page+1)."' style='color: black;'> Next Page </a></li>";
				
			echo "</ul></nav>";
    	?>	
	</div>
		
	<?php 
	$db = null;
	?>
		
<?php include('inc/footer.php'); ?>
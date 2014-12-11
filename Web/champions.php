<?php 
$pageclass="champions";
include('inc/header.php');
include('model/champion.php');
?>
	
	<?php
	include('connections.php');

	if(isset($_GET['pg'])){
		$page = $_GET['pg'];
	} else {
		$page = 0;
	}

	if(isset($_GET['numPerPage'])){
		$numPerPage = $_GET['numPerPage'];
	} else {
		$numPerPage = 50;
	}
	?>
	
	<div class="container">
		<h2>Champions</h2>
		<?php
			$query = "SELECT DISTINCT(championName) FROM `itempower` order by championName limit :numPerPage offset :offset";
			$stmt = $db->prepare($query);
			$stmt->bindValue(':numPerPage', $numPerPage, PDO::PARAM_INT);
			$stmt->bindValue(':offset', $page*$numPerPage, PDO::PARAM_INT);
			$stmt->execute();
			$results = $stmt->fetchAll();
			
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
		echo "<nav style='margin-left:25%;'><ul class='pagination'>";
		
			echo "<li ";
			if($page==0) echo "class='disabled'><a href='#'>";
			else echo "><a href='champions.php?pg=".($page-1)."'>";			
			echo "<span aria-hidden='true'>&laquo;</span><span class='sr-only'>Previous</span></a></li>";
			
			for($i=0;$i<=2;$i++) {
				echo "<li ";
				if($page==$i) echo "class='active'><a href='#'>";
				else echo "><a href='champions.php?pg=".$i."'>";

				if($i==0) {
					echo "Aatrox - Leblanc";
				} else if ($i==1) {
					echo "Lee Sin - Twisted Fate";
				} else if ($i==2) {
					echo "Twitch - Zyra";
				}

				if($page==$i) echo "<span class='sr-only'>(current)</span>";

				echo "</a></li>";
			}

			echo "<li ";
			if($page==2) echo "class='disabled'><a href='#'>";
			else echo "><a href='champions.php?pg=".($page+1)."'>";
			echo "<span aria-hidden='true'>&raquo;</span><span class='sr-only'>Next</span></a></li>";
			
		echo "</ul></nav>";
		?>
	</div>
		
	<?php 
	$db = null;
	?>
		
<?php include('inc/footer.php'); ?>
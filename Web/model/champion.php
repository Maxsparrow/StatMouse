<?php

class Champion {

	var $name;
	
	function Champion($name){
		$this->name = $name;
	}
	
	function GetChampionPageUrl(){
		return "champion.php?champion=".htmlentities($this->name, ENT_QUOTES);
	}
	
	function GetImagePath(){
		$imagePath = "/img/champions/".$this->name;
		$replace = array("."," ","'"); 
		$imagePath = str_replace($replace, "", $imagePath); 
		return $imagePath.".png";
	}
	
}


?>
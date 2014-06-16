(:~
: This is the Care Services Discovery stored query registry
: @version 1.1
: @see https://github.com/his-interop/openinfoman
:
:)
module namespace osf = "https://github.com/his-interop/openinfoman/opensearch_feed";


(:Import other namespaces.  Set default namespace  to os :)
import module namespace csd_webconf =  "https://github.com/his-interop/openinfoman/csd_webconf" at "../repo/csd_webapp_config.xqm";
import module namespace csr_proc = "https://github.com/his-interop/openinfoman/csr_proc" at "../repo/csr_processor.xqm";
import module namespace csd_dm = "https://github.com/his-interop/openinfoman/csd_dm" at "../repo/csd_document_manager.xqm";
import module namespace functx = 'http://www.functx.com';

declare namespace xs = "http://www.w3.org/2001/XMLSchema";
(:declare namespace   xforms = "http://www.w3.org/2002/xforms"; :)
declare namespace   csd = "urn:ihe:iti:csd:2013";
declare namespace os = "http://a9.com/-/spec/opensearch/1.1/";
declare namespace rss = "http://backend.userland.com/rss2";
declare namespace atom = "http://www.w3.org/2005/Atom";
declare namespace html = "http://www.w3.org/1999/xhtml";

declare function osf:is_search_function($search_name) {
  let $function := csr_proc:get_function_definition($csd_webconf:db,$search_name)
  let $ext_desc := $function//csd:extension[ @type='description' and @urn='urn:openhie.org:openinfoman:opensearch_feed']
  let $ext_link := $function//csd:extension[ @type='entity_link' and @urn='urn:openhie.org:openinfoman:opensearch_feed']

  return (exists($ext_desc) and exists($ext_link)) 
};

declare function osf:has_feed($search_name,$doc_name) {
  (osf:is_search_function($search_name) and csd_dm:is_registered($csd_webconf:db ,$doc_name))
};

declare function osf:get_description($search_name,$doc_name) {
  let $base_url := osf:get_base_url($search_name)
  let $url_template := concat(osf:get_base_url($search_name),"/", $doc_name, "/search?searchTerms={searchTerms}&amp;startPage={startPage?}&amp;startIndex={startIndex?}&amp;count={count?}")
  let $function := csr_proc:get_function_definition($csd_webconf:db,$search_name)
  let $function_desc := $function/csd:extension[@type='description' and @urn='urn:openhie.org:openinfoman:opensearch_feed']

  let $description :=
  <os:OpenSearchDescription >
   {(
     $function_desc/os:ShortName,
     $function_desc/os:Description,
     $function_desc/os:Tags,
     $function_desc/os:Contact
   )}
    <os:Url type="application/atom+xml"   template="{$url_template}&amp;format=atom"/>
   <os:Url type="application/rss+xml"   template="{$url_template}&amp;format=rss"/>
   <os:Url type="text/html"  template="{$url_template}&amp;format=html"/>

   {(
     $function_desc/os:LongName,
     $function_desc/os:Image,
     $function_desc/os:Query,
     $function_desc/os:Developer,
     $function_desc/os:Attribution
   )}
   
   <os:SyndicationRight>open</os:SyndicationRight>
   <os:AdultContent>false</os:AdultContent>
   {$function_desc/os:Language}
   <os:OutputEncoding>UTF-8</os:OutputEncoding>
   <os:InputEncoding>UTF-8</os:InputEncoding>
  </os:OpenSearchDescription>
  return $description
};


(:generate requetsed feed against the given document and care services request:)
declare function osf:get_feed($doc_name,$care_services_request)
{
  let $feed := csr_proc:process_CSR(
    $csd_webconf:db,
    $care_services_request,
    csd_dm:open_document($csd_webconf:db,$doc_name)
    )  
 return $feed
};






declare function osf:create_feed_from_entities($matched_entities,$careServicesRequest,$search_name,$rss_func,$atom_func,$html_func)  
{

  let $doc_name := $careServicesRequest/resource
  let $format:= $careServicesRequest/format/text()
  let $entities := osf:limit_matches($matched_entities,$careServicesRequest)
  let $items:= if ($format = 'rss') then 
    for $entity in $entities
    return $rss_func($entity, $doc_name,$search_name)
  else if ($format = 'atom') then
    for $entity in $entities
    return $atom_func($entity, $doc_name,$search_name)
  else 
    for $entity in $entities
    return $html_func($entity, $doc_name,$search_name)

  let $search_terms := $careServicesRequest/os:searchTerms/text()
  let $start_page := $careServicesRequest/os:startPage/text()
  let $start_index := $careServicesRequest/os:startIndex/text()
  let $count := $careServicesRequest/os:itemsPerPage/text()
  let $type := $careServicesRequest/type/text()
  let $link := concat(osf:get_base_url($search_name,$careServicesRequest/searchURL),'/' , $careServicesRequest/resource ,'/search' )
  let $function := csr_proc:get_function_definition($csd_webconf:db,$search_name)
  let $title := $function/csd:extension[@type='description' and @urn='urn:openhie.org:openinfoman:opensearch_feed']/os:ShortName/text()
  let $total := count($matched_entities)
  let $os_query :=   
    (
    <atom:title>{$title}</atom:title> 
    ,<atom:link  href="{$link}"/>
    ,<os:totalResults>{$total}</os:totalResults>
    ,<os:startIndex>{$start_index}</os:startIndex>
    ,<os:itemsPerPage>{$count}</os:itemsPerPage>
    ,<os:Query role="request" 
      searchTerms="{$search_terms}" 
      startPage="{$start_page}" 
      startIndex="{$start_index}" 
      totalResults="{$total}"       
      count="{$count}"/>
    )

  let $begin := 
    if($start_page > 0) then
       $start_page * $count
    else
       $start_index

  return if ($format = 'rss') then 
     <rss:rss version="2.0" >
       <rss:channel>
	 <rss:title>{$title}</rss:title> 
	 <rss:link>{$link}</rss:link>  
	 <rss:description>Search results for  "{$search_terms}" for search: {$title}</rss:description> 
	 <rss:language>en-US</rss:language>
	 {$os_query}
	 {$items}
       </rss:channel>
     </rss:rss>
  else if ($format = 'atom') then 
    <atom:feed xmlns:atom="http://www.w3.org/2005/Atom"     
          xmlns:os="http://a9.com/-/spec/opensearch/1.1/">
      <atom:updated>{current-dateTime()}</atom:updated>
      {(
	$os_query
        ,for $rel in ('self','first','previous','next','last','search') 
         let $atom_link := osf:get_atom_search_link($search_name,$careServicesRequest,$rel,$total)
         return <atom:link rel="{$rel}" href="{$atom_link}" type="application/atom+xml"/>
	,$items
      )} 
    </atom:feed>
  else 
    <html:html xml:lang="en" lang="en">
      <html:head profile="http://a9.com/-/spec/opensearch/1.1/" >
        <html:title>{$title}></html:title>
        <html:link rel="search"
          type="application/opensearchdescription+xml" 
          href="{osf:get_base_url($search_name,$careServicesRequest/searchURL)}"
          title="{$title}" />
        <html:meta name="totalResults" content="{$total}"/>
        <html:meta name="startIndex" content="{$start_index}"/>
        <html:meta name="itemsPerPage" content="{$count}"/>
      </html:head>
      <html:body>
        <html:h1>{$title}</html:h1>
	<html:div class='search_box' id = '{$doc_name}'>
	  <html:img src='http://upload.wikimedia.org/wikipedia/commons/7/74/GeoGebra_icon_geogebra.png'/>
	  <html:form class='seach_form' action='{concat(osf:get_base_url($search_name,$careServicesRequest/searchURL),'/' , $careServicesRequest/resource ,'/search' )}'>
	    <html:label for='{$doc_name}:{$search_name}'>Search Again</html:label> 
	    <html:input type='text' id='{$doc_name}:{$search_name}' name='searchTerms'/>
	    <html:input type='submit'>Go</html:input>
	  </html:form>
	</html:div>
        <html:div class='search_results' id='{$doc_name}'>
	  <html:h1>Search Results</html:h1>
	  <html:ul>{$items}</html:ul>
	</html:div>
      </html:body>
    </html:html>
};

declare function osf:limit_matches($nodes as node()*, $careServicesRequest) as node()*
{
  let $t_start_page := xs:int($careServicesRequest/os:startPage/text())
  let $start_page := if (exists($t_start_page)) then  max((0,$t_start_page)) else 0
  let $t_start_index := xs:int($careServicesRequest/os:startIndex/text())
  let $start_index := if (exists($t_start_index)) then  max((0,$t_start_index)) else 0
  let $t_count := xs:int($careServicesRequest/os:itemsPerPage/text())
  let $count := if (exists($t_count)) then max((1,$t_count)) else 1
  let $begin := 
    if($start_page > 0)
      then
        $start_page * $count
      else
        $start_index
  let $max := count($nodes)
  let $end := min (($begin + $count ,$max))
  return subsequence($nodes,1,10)
  (:return subsequence($nodes,$begin,($end+1)):)
};




declare function osf:get_base_url($search_name) {
  osf:get_base_url($search_name,$csd_webconf:baseurl)
};
declare function osf:get_base_url($search_name,$base_url) {
  concat($base_url,'CSD/opensearch/' ,$search_name)
};

declare function osf:get_expires($search_name) {
  current-dateTime() +  xs:dayTimeDuration("P0DT1H0M0S")   (: 0 days, 1 hour, 0 minutes, 0 seconds :)
};

declare function osf:get_entity_link($entity,$search_name) 
{
  let $function := csr_proc:get_function_definition($csd_webconf:db,$search_name)
  let $function_link := $function/csd:extension[@type='entity_link' and @urn='urn:openhie.org:openinfoman:opensearch_feed']
  return concat($function_link,$entity/@oid)
};



declare function osf:get_atom_search_link($search_name,$careServicesRequest,$rel,$total) {
  if ($rel = 'search') then
   <atom:link rel="search" href="{osf:get_base_url($search_name,$careServicesRequest/searchURL)}" type="application/atom+xml"/>
  else 
   let $start_index := if(functx:is-a-number($careServicesRequest/os:startIndex)) then max(xs:int($careServicesRequest/os:startIndex),1) else 1
   let $start_page := if(functx:is-a-number($careServicesRequest/os:startPage)) then max(xs:int($careServicesRequest/os:startPage),1) else 1
   let $records := if(functx:is-a-number($careServicesRequest/os:itemsPerPage)) then  max(xs:int($careServicesRequest/os:itemsPerPage),1) else 50
   let $url0 := concat(osf:get_base_url($search_name,$careServicesRequest/searchURL),"/search?")
   let $url1:= if ($careServicesRequest/os:searchTerms) then (concat($url0,"&amp;searchTerms=", $careServicesRequest/os:searchTerms)) else $url0
   let $url2:= 
     if ($careServicesRequest/os:startPage and not($rel = ('first','previous','next','last' ))) then
      concat($url1,"&amp;startPage=", $careServicesRequest/os:startPage)
     else
	 if ($rel ='first') then concat($url1,"&amp;startPage=1")
         else if ($rel ='previous') then if ($start_page > 1) then concat($url1,"&amp;startPage=", $start_page - 1) else  concat($url1,"&amp;startPage=1")
         else if ($rel ='next') then concat($url1,"&amp;startPage=", $start_page + 1 )
         else if ($rel ='last') then concat($url1,"&amp;startPage=", ($records div $records) + 1)
         else concat($url1,"&amp;startPage=", $careServicesRequest/os:startPage)
   let $url3:= 
     if (functx:is-a-number($careServicesRequest/os:startIndex)) then
       if ($rel ='first') then concat($url2,"&amp;startIndex=1")
       else if ($rel ='previous') then if ($start_index > 1) then concat($url2,"&amp;startIndex=", $start_index - 1) else  ()
       else if ($rel ='next') then concat($url2,"&amp;startIndex=", $start_index + 1 )
       else if ($rel ='last') then concat($url2,"&amp;startIndex=", $records )
       else concat($url2,"&amp;startIndex=", $careServicesRequest/os:startIndex)
     else $url2
   let $url4:= if ($careServicesRequest/os:itemsPerPage) then (concat($url3,"&amp;count=", $records)) else $url3
   let  $url5:= if ($careServicesRequest/format) then (concat($url4,"&amp;format=", $careServicesRequest/format)) else (concat($url4,"&amp;format=html"))
   return $url5
};



declare function osf:get_provider_desc($provider,$doc_name) {
   let $csd_doc := csd_dm:open_document($csd_webconf:db,$doc_name) 
   let $demo:= $provider/csd:demographic[1]
   let $names := 
     (
       for $name in  $demo/csd:name
         return functx:trim(concat($name/csd:surname/text(), ", " ,$name/csd:forename/text() ))
       ,for $common_name in $demo/csd:name/csd:commonName
         return functx:trim($common_name/text() )
      )
   let $unique_names :=  distinct-values($names)
   return (
     for $name in $unique_names return  concat($name, ".  ")
     ,for $address in $demo/csd:address
      let $parts := (
	   "Address ("
	   , string($address/@type) 
	   ,") "
	   ,string-join($address/csd:addressLine/text(), ", ")
  	   )
      return if (count($parts) > 1) then concat(functx:trim(string-join($parts)) , ". ") else ()
     ,let $bp:= $demo/csd:contactPoint/csd:codedType[@code="BP"and @codingSchema="urn:ihe:iti:csd:2013:contactPoint"]
       return if ($bp) then ("Business Phone: " , $bp/text() , ".") else ()
     ,for $fac_ref in $provider/csd:facility/@oid
       let $fac := if ($fac_ref) then $csd_doc/csd:facilityDirectory/csd:facility[@oid = $fac_ref]  else ()
       return if ($fac) then ("Duty Post: " , $fac/csd:primaryName/text() , ".") else ()
   )
};





declare function osf:get_provider_desc_html($provider,$doc_name) {
   let $csd_doc := csd_dm:open_document($csd_webconf:db,$doc_name) 
   let $demo:= $provider/csd:demographic[1]
   let $addresses :=$demo/csd:address
   let $names := 
     (
       for $name in  $demo/csd:name
         return functx:trim(concat($name/csd:surname/text(), ", " ,$name/csd:forename/text() ))
       ,for $common_name in $demo/csd:name/csd:commonName
         return functx:trim($common_name/text() )
      )
   let $unique_names :=  distinct-values($names)
   return
   <html:div class='results_html' id='{$doc_name}'>
    <html:div class='demographic'>
      <html:h3>Health Worker</html:h3>
	 {
         if (count($unique_names) > 0 ) then 
	  <html:ul>
	    {
            for $name in $unique_names 
	    return  <html:li>{$name}</html:li>  
	    }
	  </html:ul> 
	else ()
	  }
     </html:div>
     <html:div class='addresses'>
       <html:h3>Addresses</html:h3>
       {
	 if (count($addresses)> 0) then 
	   <html:ul> 
	     {
             for $address in $addresses
	     return
	       <html:li class='address'>
	         Address ( {string($address/@type) } ) 
		 <html:ul> 
		   { 
		   for $line in $address/csd:addressLine return <li>{$line/text()}</li> 
		   }
		 </html:ul>
	       </html:li>
	      }
          </html:ul>
         else ()
  	}
     </html:div>
     <html:div class='business_contact'>
       <html:h3>Business Contact</html:h3>
       {
	 let $bp:= $demo/csd:contactPoint/csd:codedType[@code="BP"and @codingSchema="urn:ihe:iti:csd:2013:contactPoint"]
	 return if ($bp) then concat("Business Phone: " , $bp/text() , ".") else ()
       }
     </html:div>
     <html:div class='duty_post'>
       <html:h3>Duty Posts</html:h3>
       <html:ul>
        {for $fac in $provider/csd:facility
	 return  
	  <li>
	    Duty Post: 
	    { 
	      $csd_doc/csd:facilityDirectory/csd:facility[@oid = $fac/@oid]/csd:primaryName/text() 
	    } 
	  </li>
	}
       </html:ul>
     </html:div>
     <html:div class='source'>
       <h4>Data Source</h4>{string($doc_name)}
     </html:div>
   </html:div>
};



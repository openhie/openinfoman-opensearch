(:~
: This is the Care Services Discovery stored query registry
: @version 1.1
: @see https://github.com/openhie/openinfoman
:
:)
module namespace osf = "https://github.com/openhie/openinfoman/adapter/opensearch";


(:Import other namespaces.  Set default namespace  to os :)
import module namespace csd_webconf =  "https://github.com/openhie/openinfoman/csd_webconf";
import module namespace csr_proc = "https://github.com/openhie/openinfoman/csr_proc";
import module namespace csd_dm = "https://github.com/openhie/openinfoman/csd_dm";
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
  let $ext_desc := $function//csd:extension[ @type='description' and @urn='urn:openhie.org:openinfoman:adapter:opensearch']
  let $ext_link := $function//csd:extension[ @type='entity_link' and @urn='urn:openhie.org:openinfoman:adapter:opensearch']

  return (exists($ext_desc) and exists($ext_link)) 
};

declare function osf:has_feed($search_name,$doc_name) {
  (osf:is_search_function($search_name) and csd_dm:is_registered($csd_webconf:db ,$doc_name))
};

declare function osf:get_description($search_name,$doc_name) {
  let $base_url := osf:get_base_url($search_name)
  let $url_template := concat(osf:get_base_url($search_name),"/", $doc_name, "/search?searchTerms={searchTerms}&amp;startPage={startPage?}&amp;startIndex={startIndex?}&amp;count={count?}")
  let $function := csr_proc:get_function_definition($csd_webconf:db,$search_name)
  let $function_desc := $function/csd:extension[@type='description' and @urn='urn:openhie.org:openinfoman:adapter:opensearch']
  let $short_name :=  <os:ShortName>{$function_desc/os:ShortName/text()} on {$doc_name}</os:ShortName>
  let $description :=
  <os:OpenSearchDescription >
   {(
     $short_name,
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



declare function osf:create_feed_from_entities($matched_entities,$careServicesRequest) {
  osf:create_feed_from_entities($matched_entities,$careServicesRequest,map:new(()))
};

declare function osf:create_feed_from_entities($matched_entities,$careServicesRequest,$processors as map(xs:string, function(*))) 
{
  let $format:= $careServicesRequest/format/text()
  return 
    if ($format = 'rss') then 
      osf:create_rss_feed_from_entities($matched_entities,$careServicesRequest,$processors)
    else if ($format = 'atom') then 
      osf:create_atom_feed_from_entities($matched_entities,$careServicesRequest,$processors)
    else
      osf:create_html_feed_from_entities($matched_entities,$careServicesRequest,$processors)
};


declare function osf:create_rss_feed_from_entities($matched_entities,$careServicesRequest,$processors as map(xs:string, function(*))) 
{
  let $search_name := string($careServicesRequest/@function)
  let $doc_name := string($careServicesRequest/@resource)
  let $base_url := string($careServicesRequest/@base_url)
  let $entities := osf:limit_matches($matched_entities,$careServicesRequest)
  let $func := 
      if (map:contains($processors,'rss')) then map:get($processors,'rss')
      else function($provider,$doc_name,$search_name)  {osf:get_entity_rss($provider,$doc_name,$search_name) }

  let $html_wrap_func :=
    if (map:contains($processors,'html_wrap')) then map:get($processors,'html_wrap')
    else function($meta,$content)  {osf:html_wrapper($meta,$content)}

  let $items := 
    for $entity in $entities
    return $func($entity, $doc_name,$search_name)
    

  let $search_terms := $careServicesRequest/os:searchTerms/text()
  let $start_page := $careServicesRequest/os:startPage/text()
  let $start_index := $careServicesRequest/os:startIndex/text()
  let $count := $careServicesRequest/os:itemsPerPage/text()
  let $type := $careServicesRequest/type/text()
  let $link := concat(osf:get_base_url($search_name,$base_url),'/' , $doc_name ,'/search' )
  let $function := csr_proc:get_function_definition($csd_webconf:db,$search_name)
  let $title := $function/csd:extension[@type='description' and @urn='urn:openhie.org:openinfoman:adapter:opensearch']/os:ShortName/text()
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

  return
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
};

declare function osf:create_atom_feed_from_entities($matched_entities,$careServicesRequest,$processors as map(xs:string, function(*))) 
{
  let $search_name := string($careServicesRequest/@function)
  let $doc_name := string($careServicesRequest/@resource)
  let $base_url := string($careServicesRequest/@base_url)

  let $entities := osf:limit_matches($matched_entities,$careServicesRequest)
  let $func := 
      if (map:contains($processors,'atom')) then map:get($processors,'atom')
      else function($provider,$doc_name,$search_name)  {osf:get_entity_atom($provider,$doc_name,$search_name) }

  let $items := 
    for $entity in $entities
    return $func($entity, $doc_name,$search_name)
    

  let $search_terms := $careServicesRequest/os:searchTerms/text()
  let $start_page := $careServicesRequest/os:startPage/text()
  let $start_index := $careServicesRequest/os:startIndex/text()
  let $count := $careServicesRequest/os:itemsPerPage/text()
  let $type := $careServicesRequest/type/text()
  let $link := concat(osf:get_base_url($search_name,$base_url),'/' , $doc_name ,'/search' )
  let $function := csr_proc:get_function_definition($csd_webconf:db,$search_name)
  let $title := $function/csd:extension[@type='description' and @urn='urn:openhie.org:openinfoman:adapter:opensearch']/os:ShortName/text()
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
  return 
    <atom:feed xmlns:atom="http://www.w3.org/2005/Atom"     
          xmlns:os="http://a9.com/-/spec/opensearch/1.1/">
      <atom:updated>{current-dateTime()}</atom:updated>
      {(
	$os_query
        ,for $rel in ('self','first','previous','next','last','search') 
         let $atom_link := osf:get_atom_search_link($careServicesRequest,$rel,$total)
         return <atom:link rel="{$rel}" href="{$atom_link}" type="application/atom+xml"/>
	,$items
      )} 
    </atom:feed>
};

declare function osf:create_html_feed_from_entities($matched_entities,$careServicesRequest,$processors as map(xs:string, function(*))) 
{
  let $search_name := string($careServicesRequest/@function)
  let $doc_name := string($careServicesRequest/@resource)
  let $base_url := string($careServicesRequest/@base_url)

  let $entities := osf:limit_matches($matched_entities,$careServicesRequest)

  let $func := 
    if (map:contains($processors,'html')) then map:get($processors,'html')
    else function($provider,$doc_name,$search_name)  {osf:get_entity_html($provider,$doc_name,$search_name) }

  let $html_wrap_func :=
    if (map:contains($processors,'html_wrap')) then map:get($processors,'html_wrap')
    else function($meta,$content)  {osf:html_wrapper($meta,$content)}

  let $items := 
    for $entity in $entities
    return $func($entity, $doc_name,$search_name)
    
  let $start_index := $careServicesRequest/os:startIndex/text()
  let $count := $careServicesRequest/os:itemsPerPage/text()
  let $function := csr_proc:get_function_definition($csd_webconf:db,$search_name)
  let $title := $function/csd:extension[@type='description' and @urn='urn:openhie.org:openinfoman:adapter:opensearch']/os:ShortName/text()
  let $total := count($matched_entities)

  let $content :=
	(
        <html:h1>{$title}</html:h1>
	,<html:div class='search_box' id = '{$doc_name}'>
	  <html:form class='seach_form' action='{concat(osf:get_base_url($search_name,$base_url),'/' , $doc_name ,'/search' )}'>
	    <html:label for='{$doc_name}:{$search_name}'>Search Again</html:label> 
	    <html:input type='text' id='{$doc_name}:{$search_name}' name='searchTerms'/>
	    <html:input type='submit'>Go</html:input>
	  </html:form>
	</html:div>
        ,<html:div class='search_results' id='{$doc_name}'>
	  <html:h1>Search Results</html:h1>
	  <html:ul>{$items}</html:ul>
	</html:div>
	)

   let $meta:= (
        <html:title>{$title}></html:title>
        ,<html:link rel="search"
          type="application/opensearchdescription+xml" 
          href="{osf:get_base_url($search_name,$base_url)}"
          title="{$title}" />
        ,<html:meta name="totalResults" content="{$total}"/>
        ,<html:meta name="startIndex" content="{$start_index}"/>
        ,<html:meta name="itemsPerPage" content="{$count}"/>
	 )
   return $html_wrap_func($meta,$content)
};




declare function osf:html_wrapper($meta,$content) {
<html:html xml:lang="en" lang="en">
   <html:head profile="http://a9.com/-/spec/opensearch/1.1/" >    

    <html:link href="/static/bootstrap/css/bootstrap.css" rel="stylesheet"/>
    <html:link href="/static/bootstrap/css/bootstrap-theme.css" rel="stylesheet"/>
    
    <html:script src="https://code.jquery.com/jquery.js"/>
    <script src="/static/bootstrap/js/bootstrap.min.js"/>

    <html:script src="https://code.jquery.com/jquery.js"/>
    <html:script src="/static/bootstrap/js/bootstrap.min.js"/>
    {$meta}
  </html:head>
  <html:body>  
    <html:div class="navbar navbar-inverse navbar-static-top">
      <html:div class="container">
        <html:div class="navbar-header">
	  <html:img class='pull-left' height='38px' src='http://upload.wikimedia.org/wikipedia/commons/7/74/GeoGebra_icon_geogebra.png'/>
          <html:button type="button" class="navbar-toggle" data-toggle="collapse" data-target=".navbar-collapse">
            <html:span class="icon-bar"></html:span>
            <html:span class="icon-bar"></html:span>
            <html:span class="icon-bar"></html:span>
          </html:button>
          <html:a class="navbar-brand" href="/CSD">OpenInfoMan</html:a>
        </html:div>
      </html:div>
    </html:div>
    <html:div class='wrapper_search'>
      <html:div class="container">
	{$content}
      </html:div>
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
  concat($base_url,'CSD/adapter/opensearch/' ,$search_name)
};

declare function osf:get_expires($search_name) {
  current-dateTime() +  xs:dayTimeDuration("P0DT1H0M0S")   (: 0 days, 1 hour, 0 minutes, 0 seconds :)
};

declare function osf:get_entity_link($entity,$search_name) 
{
  let $function := csr_proc:get_function_definition($csd_webconf:db,$search_name)
  let $function_link := $function/csd:extension[@type='entity_link' and @urn='urn:openhie.org:openinfoman:adapter:opensearch']
  return concat($function_link,$entity/@oid)
};



declare function osf:get_atom_search_link($careServicesRequest,$rel,$total) {
  let $base_url := string($careServicesRequest/@base_url)
  let $search_name := string($careServicesRequest/@function)
  return
    if ($rel = 'search') then
      <atom:link rel="search" href="{osf:get_base_url($search_name,$base_url)}" type="application/atom+xml"/>
    else 
      let $start_index := if(functx:is-a-number($careServicesRequest/os:startIndex)) then max(xs:int($careServicesRequest/os:startIndex),1) else 1
      let $start_page := if(functx:is-a-number($careServicesRequest/os:startPage)) then max(xs:int($careServicesRequest/os:startPage),1) else 1
      let $records := if(functx:is-a-number($careServicesRequest/os:itemsPerPage)) then  max(xs:int($careServicesRequest/os:itemsPerPage),1) else 50
      let $url0 := concat(osf:get_base_url($search_name,$base_url),"/search?")
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
     ,let $bp:= $demo/csd:contactPoint/csd:codedType[@code="BP"and @codingScheme="urn:ihe:iti:csd:2013:contactPoint"]
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
	 let $bp:= $demo/csd:contactPoint/csd:codedType[@code="BP"and @codingScheme="urn:ihe:iti:csd:2013:contactPoint"]
	 return if ($bp) then concat("Business Phone: " , $bp/text() , ".") else ()
       }
     </html:div>
     <html:div class='duty_post'>
       <html:h3>Duty Posts</html:h3>
       <html:ul>
        {for $fac in $provider/csd:facilities/csd:facility
	 return  
	  <html:li>
	    Duty Post: 
	    { 
	      $csd_doc/csd:facilityDirectory/csd:facility[@oid = $fac/@oid]/csd:primaryName/text() 
	    } 
	  </html:li>
	}
       </html:ul>
     </html:div>
     <html:div class='source'>
       <h4>Data Source</h4> {string($doc_name)}
     </html:div>
   </html:div>
};





declare function osf:get_provider_atom($provider,$doc_name,$search_name) 
{
   let $demo:= $provider/csd:demographic[1]
   return
     <atom:entry>
       <atom:title>{$demo/csd:name[1]/csd:surname/text()}, {$demo/csd:name[1]/csd:forename/text()}</atom:title>
       <atom:link href="{osf:get_entity_link($provider,$search_name)}"/>
       <atom:id>urn:oid:{string($provider/@oid)}</atom:id>  
       <atom:updated>{string($provider/csd:record/@updated)}</atom:updated>
       <atom:content type="text">{osf:get_provider_desc($provider,$doc_name)}</atom:content>
     </atom:entry>

};

declare function osf:get_provider_rss($provider,$doc_name,$search_name)
{
   let $demo:= $provider/csd:demographic[1]
   return 
     <rss:item>
       <rss:title>{$demo/csd:name[1]/csd:surname/text()}, {$demo/csd:name[1]/csd:forename/text()}</rss:title>
       <rss:link>{osf:get_entity_link($provider,$search_name)}</rss:link>
       <rss:pubDate>{string($provider/csd:record/@updated)}</rss:pubDate>
       <rss:source>{string($provider/csd:record/@sourceDirectory)}</rss:source>
       <rss:description type="text">{osf:get_provider_desc($provider,$doc_name)}</rss:description>
     </rss:item>
};


declare function osf:get_entity_html($entity,$doc_name,$search_name) {
  if (local-name-from-QName(node-name($entity)) = 'provider' and namespace-uri-from-QName(node-name($entity)) = "urn:ihe:iti:csd:2013") then
   osf:get_provider_html($entity,$doc_name,$search_name) 
 else 
   ()
};

declare function osf:get_entity_atom($entity,$doc_name,$search_name) {
 if (local-name-from-QName($entity) = 'provider' and namespace-uri-from-QName($entity) = "urn:ihe:iti:csd:2013") then
   osf:get_provider_atom($entity,$doc_name,$search_name) 
 else 
   ()
};

declare function osf:get_entity_rss($entity,$doc_name,$search_name) {
 if (local-name-from-QName($entity) = 'provider' and namespace-uri-from-QName($entity) = "urn:ihe:iti:csd:2013") then
   osf:get_provider_rss($entity,$doc_name,$search_name) 
 else 
   ()
};

declare function osf:get_provider_html($provider ,$doc_name,$search_name) 
{
  let $demo:= $provider/csd:demographic[1]
  return 
  <html:li>
    <html:a href="{osf:get_entity_link($provider,$search_name)}">
      {$demo/csd:name[1]/csd:surname/text()}, {$demo/csd:name[1]/csd:forename/text()}
    </html:a>
    <html:div class='description_html'>{osf:get_provider_desc_html($provider,$doc_name)}</html:div>
  </html:li>
  
};

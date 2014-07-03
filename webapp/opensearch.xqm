module namespace page = 'http://basex.org/modules/web-page';

(:Import other namespaces.  :)
import module namespace csd_webconf =  "https://github.com/openhie/openinfoman/csd_webconf";
import module namespace osf = "https://github.com/openhie/openinfoman/adapter/opensearch";
import module namespace csr_proc = "https://github.com/openhie/openinfoman/csr_proc";
import module namespace csd_dm = "https://github.com/openhie/openinfoman/csd_dm";
declare namespace xs = "http://www.w3.org/2001/XMLSchema";
declare namespace csd = "urn:ihe:iti:csd:2013";
declare namespace   xforms = "http://www.w3.org/2002/xforms";
declare namespace os =  "http://a9.com/-/spec/opensearch/1.1/";





(:Supposed to be linked into header of a web-page, such as the OpenHIE Health Worker Registry Management Interface :)
declare
  %rest:path("/CSD/adapter/opensearch/{$search_name}")
  %rest:GET
  %output:method("xhtml")
  function page:show_searches_on_docs($search_name) 
{ 
  if ( osf:is_search_function($search_name)) then 
    let $searches := 
      <ul>
        {
  	  for $doc_name in csd_dm:registered_documents($csd_webconf:db)      
	  return
  	  <li>
	    <a href="{$csd_webconf:baseurl}/CSD/adapter/opensearch/{$search_name}/{$doc_name}">{string($doc_name)}</a>
	  </li>
	}
      </ul>

    let $auto_links := 
      for $doc_name in csd_dm:registered_documents($csd_webconf:db)      
      return 
        for $search_func in csr_proc:stored_functions($csd_webconf:db)[@uuid = $search_name]
	let $slink:= concat($csd_webconf:baseurl , "CSD/adapter/opensearch/" , $search_func/@uuid, "/" , $doc_name)
        let $short_name := $search_func/csd:extension[@type='description' and  @urn='urn:openhie.org:openinfoman:adapter:opensearch']/os:ShortName
	let $title := concat($short_name, " : "  ,$doc_name)
	where osf:is_search_function($search_func/@uuid)
	return 
          <link rel="search" href="{$slink}"  type="application/opensearchdescription+xml" title="{$title}" />
     let $contents := 
       <div class='container'>
        {(
	  <a href="{$csd_webconf:baseurl}CSD/adapter/opensearch">OpenSearch Adapters</a>
	  ,$searches
        )}
      </div>
   return page:wrapper($contents,$auto_links)
 else  page:wrapper(<h2>Not an OpenSearch Function</h2>,())
};









(:
Each OpenSearch upposed to be linked into header of a web-page, such as the OpenHIE Health Worker Registry Management Interface 
http://blog.unto.net/add-opensearch-to-your-site-in-five-minutes.html
:)
declare
  %rest:path("/CSD/adapter/opensearch/{$search_name}/{$doc_name}") 
  %output:media-type("text/xml")
  function page:get_description($search_name,$doc_name) 
{  
  if (osf:has_feed($search_name,$doc_name)) then

    let $description := osf:get_description($search_name,$doc_name)
    let $response := ()
(: 
        <http:response status="200" message="OK">
	<http:header name="Date" value="{current-dateTime()}"/>
	<http:header name="Content-Length" value="{string-length($description)}"/>
	<http:header name="Expires" value="{osf:get_expires($search_name)}"/>
	<http:header name="Connection" value="close"/>
	<http:header name="Content-Type" value="application/opensearchdescription+xml"/>
	<http:header name="Server" value="BaseX?"/>
	<http:header name="X-Powered-By" value="OpenInfoMan - OpenSearch"/>
	<http:header name="Cache-Control" value="max-age=90"/>
	<http:body media-type="application/opensearchdescription+xml"/>
      </http:response>
:)
    return ($response, $description) 
  else 
    <http:response status="404" message="No OpenSearch  function with registered with uuid  '{$search_name}'.">
      <http:header name="Content-Language" value="en"/>
      <http:header name="Content-Type" value="text/html; charset=utf-8"/>
    </http:response>    
};


declare
  %rest:path("/CSD/adapter/opensearch/{$search_name}/{$doc_name}/search") 
  %rest:query-param("searchTerms", "{$searchTerms}",'')  
  %rest:query-param("startPage", "{$startPage}",1)  
  %rest:query-param("startIndex", "{$startIndex}",1)  
  %rest:query-param("start", "{$start}",0)  
  %rest:query-param("count", "{$count}",50)  
  %rest:query-param("type", "{$type}","text/html")  
  %rest:query-param("format", "{$format}","html")  
  function page:get_feed($search_name,$doc_name,$searchTerms,$startPage,$start,$startIndex,$count,$type,$format)
{
   if (osf:has_feed($search_name,$doc_name)) then
    (:would be nice to figure out a good way to use the xform:instance :)
    let $care_services_request :=
      <csd:careServicesRequest >
	<csd:function uuid='{$search_name}'>
	  <requestParams>
            <os:searchTerms>{$searchTerms}</os:searchTerms>
	    <os:startPage>{$startPage}</os:startPage>
	    <os:startIndex>{$startIndex}</os:startIndex>
	    <os:itemsPerPage>{$count}</os:itemsPerPage>
	    <type>{$type}</type>
	    <format>{$format}</format>
	  </requestParams>
	</csd:function>
      </csd:careServicesRequest>
     let $results := csr_proc:process_CSR(
       $csd_webconf:db,
       $care_services_request,
       $doc_name,
       $csd_webconf:baseurl
      )   
(:     return osf:get_feed($doc_name,$care_services_request) :)
     return $results
(:    return csr_adpt:get_results($doc_name,$care_services_request,$wrapper) :) 
(:
      <rest:response>
	<http:response status="200" message="OK">
	  <http:header name="Date" value="{current-dateTime()}"/>
	  <http:header name="Expires" value="{osf:get_expires($search_name)}"/>
	  <http:header name="Connection" value="close"/>
	  <http:header name="Content-Type" value="{$type}"/>
	  <http:header name="Server" value="BaseX?"/>
	  <http:header name="X-Powered-By" value="OpenInfoMan - OpenSearch"/>
	  <http:header name="Cache-Control" value="max-age=90"/>
	  <http:body media-type="{$type}"/>
	</http:response>
      </rest:response>
:)
  else  
    <http:response status="404" message="No OpenSearch  function with registered with '{$search_name}'.">
      <http:header name="Content-Language" value="en"/>
      <http:header name="Content-Type" value="text/html; charset=utf-8"/>
    </http:response>

};





declare function page:wrapper($searches,$auto_links) {
 <html>
  <head>

    <link href="{$csd_webconf:baseurl}static/bootstrap/css/bootstrap.css" rel="stylesheet"/>
    <link href="{$csd_webconf:baseurl}static/bootstrap/css/bootstrap-theme.css" rel="stylesheet"/>
    
    {$auto_links}
    <script src="https://code.jquery.com/jquery.js"/>
    <script src="{$csd_webconf:baseurl}static/bootstrap/js/bootstrap.min.js"/>

    <script src="https://code.jquery.com/jquery.js"/>
    <script src="{$csd_webconf:baseurl}static/bootstrap/js/bootstrap.min.js"/>

  </head>
  <body>  
    <div class="navbar navbar-inverse navbar-static-top">
      <div class="container">
        <div class="navbar-header">
          <button type="button" class="navbar-toggle" data-toggle="collapse" data-target=".navbar-collapse">
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </button>
          <a class="navbar-brand" href="{$csd_webconf:baseurl}CSD">OpenInfoMan</a>
        </div>
      </div>
    </div>
    <div class='container'>
      {$searches}
    </div>
  </body>
 </html>
};



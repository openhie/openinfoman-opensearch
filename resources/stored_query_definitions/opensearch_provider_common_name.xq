import module namespace csd = "urn:ihe:iti:csd:2013" at "../repo/csd_base_library.xqm";
import module namespace osf = "https://github.com/his-interop/openinfoman/opensearch_feed" at "../repo/opensearch_feed.xqm";
import module namespace functx = 'http://www.functx.com';

declare namespace rss = "http://backend.userland.com/rss2";
declare namespace atom = "http://www.w3.org/2005/Atom";
declare namespace html = "http://www.w3.org/1999/xhtml";
declare namespace os  = "http://a9.com/-/spec/opensearch/1.1/";
declare variable $careServicesRequest as item() external;



(: 
   The query will be executed against the root element of the CSD document.    
   The dynamic context of this query has $careServicesRequest set to contain any of the search 
   and limit paramaters as sent by the Service Finder
:) 

(:Should match the UUID assigned to the care services function.  :)
let $search_name := "48095e0e-7760-46bc-8798-c4fa857a878c"


(:Get the search terms passed in the request :)
let $search_terms := $careServicesRequest/os:searchTerms/text()
(:Find the matching providers -- to be customized for your search:)
let $matched_providers :=  
  for $provider in /csd:CSD/csd:providerDirectory/csd:provider
  where  functx:contains-case-insensitive($provider/csd:demographic/csd:name/csd:commonName,  $search_terms)  
  return $provider  


(:function that produces the atom entry for a provider.:)
let $atom_func:= function($provider,$doc_name,$search_name) 
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

}

(:function that produces the rss entry for a provider.:)
let $rss_func := function($provider,$doc_name,$search_name) 
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
}

(:function that produces the html entry for a provider.:)
let $html_func := function($provider,$doc_name,$search_name) 
{
   let $demo:= $provider/csd:demographic[1]
   return 
     <html:li>
       <html:a href="{osf:get_entity_link($provider,$search_name)}">
	 {$demo/csd:name[1]/csd:surname/text()}, {$demo/csd:name[1]/csd:forename/text()}
       </html:a>
       <html:div class='description'>{osf:get_provider_desc($provider,$doc_name)}</html:div>
     </html:li>
     
}



(:Produce the feed in the neccesary format :)
return osf:create_feed_from_entities($matched_providers,$careServicesRequest,$search_name,$rss_func,$atom_func,$html_func) 




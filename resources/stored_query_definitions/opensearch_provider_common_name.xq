import module namespace osf = "https://github.com/his-interop/openinfoman/opensearch_feed";
import module namespace functx = 'http://www.functx.com';

declare namespace csd =  "urn:ihe:iti:csd:2013";
declare namespace rss = "http://backend.userland.com/rss2";
declare namespace atom = "http://www.w3.org/2005/Atom";
declare namespace html = "http://www.w3.org/1999/xhtml";
declare namespace os  = "http://a9.com/-/spec/opensearch/1.1/";

declare variable $careServicesRequest as item() external;
declare variable $base_url  external;
declare variable $doc_name  external;



(: 
   The query will be executed against the root element of the CSD document.    
   The dynamic context of this query has $careServicesRequest set to contain any of the search 
   and limit paramaters as sent by the Service Finder
:) 

(:Should match the UUID assigned to the care services function.  :)
let $search_name := "48095e0e-7760-46bc-8798-c4fa857a878c"

(:Get the search terms passed in the request :)
let $search_terms := xs:string($careServicesRequest/os:searchTerms/text())
(:Find the matching providers -- to be customized for your search:)
let $matched_providers :=  
  for $provider in /csd:CSD/csd:providerDirectory/csd:provider
  let $common_name := $provider/csd:demographic/csd:name/csd:commonName
  where  exists($search_terms) and exists($common_name) and functx:contains-case-insensitive($common_name,  $search_terms)  
  return $provider  



(:Produce the feed in the neccesary format :)
return osf:create_feed_from_entities($matched_providers,$careServicesRequest,$base_url,$search_name,$doc_name)




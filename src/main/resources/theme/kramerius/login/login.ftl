<#import "template.ftl" as layout>

<#-- <script src="${url.resourcesCommonPath}/node_modules/jquery/dist/jquery.min.js" type="text/javascript"></script>  -->
    <script src="${url.resourcesCommonPath}/node_modules/angular/angular.min.js"></script>


    <script>
        var idpLoginFullUrl = '${idpLoginFullUrl?no_esc}';
    </script>


	<script>

		var angularLoginPart = angular.module("angularLoginPart", []);

        angularLoginPart.directive("onScroll", [function () {
            var previousScroll = 0;
            var link = function ($scope, $element, attrs) {
                $element.bind('scroll', function (evt) {
                    var currentScroll = $element.scrollTop;
                    $scope.$eval(attrs["onScroll"], {$event: evt, $direct: currentScroll > previousScroll ? 1 : -1});
                    previousScroll = currentScroll;
                });
            };
            return {
                restrict: "A",
                link: link
            };
        }]);



		angularLoginPart.controller("idpListing", function($scope, $http, $location) {

            var sessionParams = new URL(baseUriOrigin+idpLoginFullUrl).searchParams;

            $scope.fetchParams = { 'keyword': '', 'first' : null, 'max': null, 'client_id': sessionParams.get('client_id'), 'tab_id': sessionParams.get('tab_id'), 'session_code': sessionParams.get('session_code')};
            $scope.idps = [];
            $scope.hiddenIdps = 0;
            $scope.totalIdpsAskedFor = 0;
            $scope.reachedEndPage = false;
            $scope.latestSearch = {};  //for sync purposes
            $scope.isSearching = false;
            $scope.isKrameriusAdmin = false;


			$scope.isIdpPartHidden = function() {
				var currentUrl = $location.url();

				var showAll = currentUrl.endsWith('#all');
				var showIdp = currentUrl.endsWith('#idp');

				if (currentUrl.indexOf('#') == -1) {
					showAll = true;
				}
						
						
				var retval =  !(showAll || showIdp);
				return retval;
				
			};

			$scope.isFormPartHidden = function() {
				var currentUrl = $location.url();
				var showAll = currentUrl.endsWith('#all');
				var showForm =  currentUrl.endsWith('#form');
	
				if (currentUrl.indexOf('#') == -1) {
					showAll = true;
				}
						
				var retval = !(showAll || showForm)
				return retval;
				
			};


			getIdps();

            function handleAngularForm() {
                $http({method: 'GET', url: baseUri + '/realms/' + realm + '/theme-info/theme-config' })
                    .then(
                        function(success) {
                            var adminUrls = success.data['krameriusAdminUrls'];
                            checkRedirectUri(adminUrls);
                        }
                    );
            }

            function checkRedirectUri(adminUrls) {
                var params = {
                        'client_id': $scope.fetchParams['client_id'], 
                        'tab_id': $scope.fetchParams['tab_id'], 
                        'session_code': $scope.fetchParams['session_code']
                }
                $http({method: 'GET', url: baseUri + '/realms/' + realm + '/theme-info/redirect-uri', params : params })
                    .then(
                        function(success) {
                            var redirectUri = success.data['redirect_uri'];
                            var url = new URL(redirectUri);
                            var urlHostname = url.hostname;
                            for (var i = 0; i < adminUrls.length; i++) {
                                console.log(adminUrls[i] + ' ?= '+ urlHostname)
                                if (adminUrls[i] == urlHostname) {
                                    $scope.isKrameriusAdmin = true;
                                }
                            }
                            /*
							if(!$scope.isKrameriusAdmin) {
                            } else {
                                document.getElementById("kc-page-title").textContent="Kramerius Admin";
                            }*/
                        }
                    );
            }

            function setLoginUrl(idp) {
                idp.loginUrl = baseUriOrigin + idpLoginFullUrl.replace("/_/", "/"+idp.alias+"/");
            }


            // Function also sets English name
            function setLogo(idp) {
                $http({method: 'GET', url: baseUri + '/realms/' + realm + '/theme-info/identity-provider-logo/' + idp.alias })
                    .then(
                        function(success) {
                            idp.logo = success.data.logo;
                            // Check locale
                            // Check kc_locale first
                            const params = new URLSearchParams(window.location.search);
                            const kc_locale = params.get('kc_locale');
                            if(!kc_locale) {
                                if(window.navigator.language.split('-')[0] == "en") {
                                    idp.en_name = success.data['en-name'];
                                } else {
                                    idp.en_name = null;
                                }
                            } else {
                                if(kc_locale == "en") {
                                    idp.en_name = success.data['en-name'];
                                } else {
                                    idp.en_name = null;
                                }
                            }
                        },
                        function(error){
                            console.log("Error endpoint /identity-provider-logo");
                        }
                    );
            }

            function getIdps() {
                var submissionTimestamp = new Date().getTime(); //to let the current values be accessible within the callbacks
                var searchParams = $scope.fetchParams; //to let the current values be accessible within the callbacks
				console.log("getIDPS, searchParams:"+searchParams);
				
                $scope.latestSearch = { submissionTimestamp: submissionTimestamp, searchParams: searchParams };
                $scope.isSearching = true;
                $http({method: 'GET', url: baseUri + '/realms/' + realm + '/theme-info/identity-providers', params : $scope.fetchParams })
                    .then(
                        function(success) {
                            //if we have typed fast multiple chars in the searchbox and the search results delay, this might end up appending duplicate values. prevent it
                            if((searchParams.first == 0) && (submissionTimestamp != $scope.latestSearch.submissionTimestamp)) { //reject the results, there is a newer search
                                return;
                            }
                            $scope.isSearching = false;
                            if(success.data != null && Array.isArray(success.data.identityProviders)){
                                success.data.identityProviders.forEach(function(idp) {
                                    setLoginUrl(idp);
                                    idp.logo = null;
                                    setLogo(idp);
                                    $scope.idps.push(idp);
                                });
                                // Sort new IDPs
                                $scope.idps.sort((a, b) => a.displayName.localeCompare(b.displayName));
                                $scope.hiddenIdps = success.data.hiddenIdps;
                            }
                            else {
                                $scope.reachedEndPage = true;
                            }
                            $scope.totalIdpsAskedFor += $scope.fetchParams.max;
                        },
                        function(error){
                            $scope.isSearching = false;
                        }
                    );
            }

            function getPromotedIdps() {
                $http({method: 'GET', url: baseUri + '/realms/' + realm + '/theme-info/identity-providers-promoted' })
                    .then(
                        function(success) {
                            success.data.forEach(function(idp) {
                                setLoginUrl(idp);
                                idp.logo = null;
                                setLogo(idp);
                            });
                            $scope.promotedIdps = success.data;
                            if(window.localStorage.getItem('savedIdps') != null) {
                                getSavedIdp(window.localStorage.getItem('savedIdps'));
                            }
                        },
                        function(error){
                        }
                    );
            }

            function getSavedIdp(alias) {
                $http({method: 'GET', url: baseUri + '/realms/' + realm + '/theme-info/identity-provider-by-alias/' + alias})
                    .then(
                        function(success) {
                            success.data.forEach(function(idp) {
                                setLoginUrl(idp);
                                idp.logo = null;
                                setLogo(idp);  
                            });
                            // Push last Used IDP by user
                            // Check if last used IDP is already in Promoted Idps (Only MZK in Kramerius)
                            var duplicate = false; 
                            $scope.promotedIdps.forEach(function(idp) {
                                if(idp.alias == alias) {
                                    duplicate = true;
                                }
                            });
                            if(duplicate == false) {
                                $scope.promotedIdps.push(success.data[0]);
                            }
                        },
                        function(error){
                        }
                    );
            }

            handleAngularForm();

            getPromotedIdps();
            /*
            $scope.scrollCallback = function ($event, $direct) {
                if($scope.reachedEndPage==true || $event.target.lastElementChild==null)
                    return;
                if(($event.target.scrollTop + $event.target.clientHeight) > ($event.target.scrollHeight - $event.target.lastElementChild.clientHeight)){
                    if($scope.totalIdpsAskedFor < $scope.fetchParams.first + $scope.fetchParams.max){ //means that there is an ongoing fetching or reached the end
                        console.log("loading or reached end of stream");
                    }
                    else{
                        $scope.fetchParams.first += $scope.fetchParams.max;
                        getIdps();
                    }
                }

            };*/

            $scope.saveIdp = function ($event, $direct) {
                console.log($event.target.id);
                idpId = $event.target.id.replace('social-', '');
                window.localStorage.setItem('savedIdps', idpId);
            }

            $scope.$watch(
                "fetchParams.keyword",
                function handleChange(newValue, oldValue) {
                  if (newValue !== oldValue) {
                    $scope.idps = [];
                    $scope.hiddenIdps = 0;
                    $scope.fetchParams.first = 0;
                    $scope.totalIdpsAskedFor = 0;
                    $scope.reachedEndPage = false;
                    $scope.latestSearch = { timestamp: new Date().getTime(), keyword: newValue };
                    getIdps();
                  }
                }
            );


        });

    </script>

<@layout.registrationLayout displayMessage=!messagesPerField.existsError('username','password') displayInfo=realm.password && realm.registrationAllowed && !registrationDisabled??; section>
    <#if section = "header">
        ${msg("loginAccountTitle")}
    <#elseif section = "form">
    <div id="kc-form">
        <div ng-app="angularLoginPart" ng-controller="idpListing">
        <#-- Keycloak form starts here -->
        <div id="kc-form-wrapper" ng-hide="isFormPartHidden()">
            <#if realm.password>
                <form id="kc-form-login" onsubmit="login.disabled = true; return true;" action="${url.loginAction}" method="post">
                    <div class="${properties.kcFormGroupClass!}">
                        <label for="username" class="${properties.kcLabelClass!}"><#if !realm.loginWithEmailAllowed>${msg("username")}<#elseif !realm.registrationEmailAsUsername>${msg("usernameOrEmail")}<#else>${msg("email")}</#if></label>

                        <#if usernameEditDisabled??>
                            <input tabindex="1" id="username" class="${properties.kcInputClass!}" name="username" value="${(login.username!'')}" type="text" disabled />
                        <#else>
                            <input tabindex="1" id="username" class="${properties.kcInputClass!}" name="username" value="${(login.username!'')}"  type="text" autofocus autocomplete="off"
                                aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>"
                            />

                            <#if messagesPerField.existsError('username','password')>
                                <span id="input-error" class="${properties.kcInputErrorMessageClass!}" aria-live="polite">
                                        ${kcSanitize(messagesPerField.getFirstError('username','password'))?no_esc}
                                </span>
                            </#if>
                        </#if>
                    </div>

                    <div class="${properties.kcFormGroupClass!}">
                        <label for="password" class="${properties.kcLabelClass!}">${msg("password")}</label>

                        <input tabindex="2" id="password" class="${properties.kcInputClass!}" name="password" type="password" autocomplete="off"
                            aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>"
                        />
                    </div>

                    <div class="${properties.kcFormGroupClass!} ${properties.kcFormSettingClass!}">
                        <div id="kc-form-options">
                            <#if realm.rememberMe && !usernameEditDisabled??>
                                <div class="checkbox">
                                    <label>
                                        <#if login.rememberMe??>
                                            <input tabindex="3" id="rememberMe" name="rememberMe" type="checkbox" checked> ${msg("rememberMe")}
                                        <#else>
                                            <input tabindex="3" id="rememberMe" name="rememberMe" type="checkbox"> ${msg("rememberMe")}
                                        </#if>
                                    </label>
                                </div>
                            </#if>
                            </div>
                            <div class="${properties.kcFormOptionsWrapperClass!}">
                                <#if realm.resetPasswordAllowed>
                                    <span><a tabindex="5" href="${url.loginResetCredentialsUrl}">${msg("doForgotPassword")}</a></span>
                                </#if>
                            </div>

                    </div>

                    <div id="kc-form-buttons" class="${properties.kcFormGroupClass!}">
                        <input type="hidden" id="id-hidden-input" name="credentialId" <#if auth.selectedCredential?has_content>value="${auth.selectedCredential}"</#if>/>
                        <input tabindex="4" class="${properties.kcButtonClass!} ${properties.kcButtonPrimaryClass!} ${properties.kcButtonBlockClass!} ${properties.kcButtonLargeClass!}" name="login" id="kc-login" type="submit" value="${msg("doLogIn")}"/>
                    </div>
                </form>
            </#if>
        </div>
        <#-- Keycloak form ends here -->

        <#-- Keycloak IDP list starts here -->
        

        <div ng-if="promotedIdps!=null && promotedIdps.length>0" id="kc-social-promoted-providers" class="${properties.kcFormSocialAccountSectionClass!}" ng-hide="isIdpPartHidden()">
            <hr/>
            <ul class="${properties.kcFormSocialAccountListClass!} ">
                <a ng-repeat="idp in promotedIdps" id="social-{{idp.alias}}" class="${properties.kcFormSocialAccountListButtonClass!}" ng-class="{ '${properties.kcFormSocialAccountGridItem!}' : promotedIdps.length > 3 }" type="button" href="{{idp.loginUrl}}" ng-click="saveIdp($event)">
                    <div ng-if="idp.logo!=null">
                        <div ng-if="idp.en_name==null">
                            <span class="${properties.kcFormSocialAccountNameClass!}" style="float:left">{{idp.displayName}}</span>
                        </div>
                        <div ng-if="idp.en_name!=null">
                            <span class="${properties.kcFormSocialAccountNameClass!}" style="float:left">{{idp.en_name}}</span>
                        </div>
                        <img src="{{idp.logo}}" alt="" style="max-height: 50px;float:right;">
                    </div>
                    <div ng-if="idp.logo==null">
                        <div ng-if="idp.en_name==null">
                            <span class="${properties.kcFormSocialAccountNameClass!}" style="float:left">{{idp.displayName}}</span>
                        </div>
                        <div ng-if="idp.en_name!=null">
                            <span class="${properties.kcFormSocialAccountNameClass!}" style="float:left">{{idp.en_name}}</span>
                        </div>
                    </div>
                </a>
            </ul>
        </div>
        <div ng-if="((idps!=null && idps.length>0) || fetchParams.keyword!=null)" id="kc-social-providers" class="${properties.kcFormSocialAccountSectionClass!}" ng-hide="isIdpPartHidden()">
<#--
            <hr/>
            <h4>${msg("identity-provider-login-label")}</h4>
-->
            <div ng-if="(idps.length + hiddenIdps >= fetchParams.max && fetchParams.keyword==null) || fetchParams.keyword!=null">
                <input id="kc-providers-filter" type="text" ng-model="fetchParams.keyword">
                <i class="fa fa-search" id="kc-providers-filter-button"> </i>
            </div>
            <div style="height:0px; margin: auto;">
                <img id='spinner' src='${url.resourcesPath}/img/spinner.svg' ng-class="{'hidden' : !isSearching }" style="margin: auto; width:100px; height:100px;" />
            </div>
            <ul id="kc-providers-list" class="${properties.kcFormSocialAccountListClass!} login-pf-list-scrollable" on-scroll="scrollCallback($event, $direct)" >
               <a ng-repeat="idp in idps" id="social-{{idp.alias}}" class="${properties.kcFormSocialAccountListButtonClass!}" ng-class="{ '${properties.kcFormSocialAccountGridItem!}' : idps.length > 3 }" type="button" href="{{idp.loginUrl}}" ng-click="saveIdp($event)" style="min-height:50px;">
                  <div ng-if="idp.logo!=null">
                    <div ng-if="idp.en_name==null">
                        <span class="${properties.kcFormSocialAccountNameClass!}" style="float:left">{{idp.displayName}}</span>
                    </div>
                    <div ng-if="idp.en_name!=null">
                        <span class="${properties.kcFormSocialAccountNameClass!}" style="float:left">{{idp.en_name}}</span>
                    </div>  
                    <img src="{{idp.logo}}" alt="" style="max-height: 50px;float:right;">
                  </div>
                  <div ng-if="idp.logo==null">
                    <div ng-if="idp.en_name==null">
                        <span class="${properties.kcFormSocialAccountNameClass!}" style="float:left">{{idp.displayName}}</span>
                    </div>
                    <div ng-if="idp.en_name!=null">
                        <span class="${properties.kcFormSocialAccountNameClass!}" style="float:left">{{idp.en_name}}</span>
                    </div> 
                  </div>
               </a>
            </ul>
        </div>
      </div>

    </div>
    <#-- Keycloak IDP list ends here -->
    <#elseif section = "info" >
        <#if realm.password && realm.registrationAllowed && !registrationDisabled??>
            <div id="kc-registration-container">
                <div id="kc-registration">
                    <span>${msg("noAccount")} <a tabindex="6" href="${url.registrationUrl}">${msg("doRegister")}</a></span>
                </div>
            </div>
        </#if>
    </#if>
    <div>
</@layout.registrationLayout>
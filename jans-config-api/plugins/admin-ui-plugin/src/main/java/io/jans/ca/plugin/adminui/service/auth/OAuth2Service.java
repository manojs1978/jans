package io.jans.ca.plugin.adminui.service.auth;

import com.google.common.base.Strings;
import com.google.common.collect.Maps;
import com.google.common.collect.Sets;
import io.jans.as.client.TokenRequest;
import io.jans.as.common.service.common.EncryptionService;
import io.jans.as.model.common.GrantType;
import io.jans.as.model.jwt.Jwt;
import io.jans.as.model.jwt.JwtClaims;
import io.jans.ca.plugin.adminui.model.auth.TokenResponse;
import io.jans.ca.plugin.adminui.model.auth.UserInfoRequest;
import io.jans.ca.plugin.adminui.model.auth.UserInfoResponse;
import io.jans.ca.plugin.adminui.model.config.AUIConfiguration;
import io.jans.ca.plugin.adminui.model.exception.ApplicationException;
import io.jans.ca.plugin.adminui.rest.auth.OAuth2Resource;
import io.jans.ca.plugin.adminui.service.BaseService;
import io.jans.ca.plugin.adminui.service.config.AUIConfigurationService;
import io.jans.ca.plugin.adminui.utils.ClientFactory;
import io.jans.ca.plugin.adminui.utils.CommonUtils;
import io.jans.ca.plugin.adminui.utils.ErrorResponse;
import jakarta.inject.Inject;
import jakarta.inject.Singleton;
import jakarta.ws.rs.client.Entity;
import jakarta.ws.rs.client.Invocation;
import jakarta.ws.rs.core.MultivaluedHashMap;
import jakarta.ws.rs.core.MultivaluedMap;
import jakarta.ws.rs.core.Response;
import org.json.JSONArray;
import org.json.JSONObject;
import org.slf4j.Logger;

import java.io.UnsupportedEncodingException;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Singleton
public class OAuth2Service extends BaseService {
    @Inject
    Logger log;

    @Inject
    AUIConfigurationService auiConfigurationService;

    @Inject
    EncryptionService encryptionService;

    /**
     * Calls token endpoint from the Identity Provider and returns a valid Access Token.
     */
    public TokenResponse getAccessToken(String code, String appType) throws ApplicationException {
        try {
            log.debug("Getting access token with code");
            if (Strings.isNullOrEmpty(code)) {
                log.error(ErrorResponse.AUTHORIZATION_CODE_BLANK.getDescription());
                throw new ApplicationException(Response.Status.BAD_REQUEST.getStatusCode(), ErrorResponse.AUTHORIZATION_CODE_BLANK.getDescription());
            }
            AUIConfiguration auiConfiguration = auiConfigurationService.getAUIConfiguration(appType);

            TokenRequest tokenRequest = new TokenRequest(GrantType.AUTHORIZATION_CODE);
            tokenRequest.setCode(code);

            tokenRequest.setAuthUsername(auiConfiguration.getAuthServerClientId());
            tokenRequest.setAuthPassword(encryptionService.decrypt(auiConfiguration.getAuthServerClientSecret()));
            tokenRequest.setGrantType(GrantType.AUTHORIZATION_CODE);
            tokenRequest.setRedirectUri(auiConfiguration.getAuthServerRedirectUrl());
            tokenRequest.setScope(auiConfiguration.getAuthServerScope());
            io.jans.as.client.TokenResponse tokenResponse = getToken(tokenRequest, auiConfiguration.getAuthServerTokenEndpoint());

            TokenResponse tokenResp = new TokenResponse();
            tokenResp.setAccessToken(tokenResponse.getAccessToken());
            tokenResp.setIdToken(tokenResponse.getIdToken());
            tokenResp.setRefreshToken(tokenResponse.getRefreshToken());

            return tokenResp;
        } catch (ApplicationException e) {
            log.error(ErrorResponse.GET_ACCESS_TOKEN_ERROR.getDescription());
            throw e;
        } catch (Exception e) {
            log.error(ErrorResponse.GET_ACCESS_TOKEN_ERROR.getDescription(), e);
            throw new ApplicationException(Response.Status.INTERNAL_SERVER_ERROR.getStatusCode(), ErrorResponse.GET_ACCESS_TOKEN_ERROR.getDescription());
        }
    }

    /**
     * Calls token endpoint from the Identity Provider and returns a valid Access Token.
     */
    public TokenResponse getApiProtectionToken(String userInfoJwt, String appType) throws ApplicationException {
        try {
            log.debug("Getting api-protection token");

            AUIConfiguration auiConfiguration = auiConfigurationService.getAUIConfiguration(appType);

            TokenRequest tokenRequest = new TokenRequest(GrantType.CLIENT_CREDENTIALS);
            tokenRequest.setAuthUsername(auiConfiguration.getTokenServerClientId());
            tokenRequest.setAuthPassword(encryptionService.decrypt(auiConfiguration.getTokenServerClientSecret()));
            tokenRequest.setGrantType(GrantType.CLIENT_CREDENTIALS);
            tokenRequest.setRedirectUri(auiConfiguration.getTokenServerRedirectUrl());

            if (Strings.isNullOrEmpty(userInfoJwt)) {
                log.warn(ErrorResponse.USER_INFO_JWT_BLANK.getDescription());
                tokenRequest.setScope(scopeAsString(Arrays.asList(OAuth2Resource.SCOPE_OPENID)));
            }
            io.jans.as.client.TokenResponse tokenResponse = getToken(tokenRequest, auiConfiguration.getTokenServerTokenEndpoint(), userInfoJwt);

            final Jwt tokenJwt = Jwt.parse(tokenResponse.getAccessToken());
            Map<String, Object> claims = getClaims(tokenJwt);
            TokenResponse tokenResp = new TokenResponse();
            tokenResp.setAccessToken(tokenResponse.getAccessToken());
            tokenResp.setIdToken(tokenResponse.getIdToken());
            tokenResp.setRefreshToken(tokenResponse.getRefreshToken());
            final String SCOPE = "scope";
            if (claims.get(SCOPE) instanceof List) {
                tokenResp.setScopes((List) claims.get(SCOPE));
            }

            if (claims.get("iat") != null) {
                tokenResp.setIat(Long.valueOf(claims.get("iat").toString()));
            }

            if (claims.get("exp") != null) {
                tokenResp.setExp(Long.valueOf(claims.get("exp").toString()));
            }

            if (claims.get("iss") != null) {
                tokenResp.setIssuer(claims.get("iss").toString());
            }

            return tokenResp;
        } catch (ApplicationException e) {
            log.error(ErrorResponse.GET_ACCESS_TOKEN_ERROR.getDescription());
            throw e;
        } catch (Exception e) {
            log.error(ErrorResponse.GET_API_PROTECTION_TOKEN_ERROR.getDescription(), e);
            throw new ApplicationException(Response.Status.INTERNAL_SERVER_ERROR.getStatusCode(), ErrorResponse.GET_API_PROTECTION_TOKEN_ERROR.getDescription());
        }
    }

    public UserInfoResponse getUserInfo(UserInfoRequest userInfoRequest, String appType) throws ApplicationException {
        try {
            log.debug("Getting User-Info from auth-server: {}", userInfoRequest.getAccessToken());
            AUIConfiguration auiConfiguration = auiConfigurationService.getAUIConfiguration(appType);

            String accessToken = org.apache.logging.log4j.util.Strings.isNotBlank(userInfoRequest.getAccessToken()) ? userInfoRequest.getAccessToken() : null;

            if (Strings.isNullOrEmpty(userInfoRequest.getCode()) && Strings.isNullOrEmpty(accessToken)) {
                log.error(ErrorResponse.CODE_OR_TOKEN_REQUIRED.getDescription());
                throw new ApplicationException(Response.Status.BAD_REQUEST.getStatusCode(), ErrorResponse.CODE_OR_TOKEN_REQUIRED.getDescription());
            }

            if (org.apache.logging.log4j.util.Strings.isNotBlank(userInfoRequest.getCode()) && org.apache.logging.log4j.util.Strings.isBlank(accessToken)) {
                TokenResponse tokenResponse = getAccessToken(userInfoRequest.getCode(), appType);
                accessToken = tokenResponse.getAccessToken();
            }
            log.debug("Access Token : {}", accessToken);

            MultivaluedMap<String, String> body = new MultivaluedHashMap<>();
            body.putSingle("access_token", accessToken);

            Invocation.Builder request = ClientFactory.instance().getClientBuilder(auiConfiguration.getAuthServerUserInfoEndpoint());
            request.header("Authorization", "Bearer " + accessToken);

            Response response = request
                    .post(Entity.form(body));

            log.debug("User-Info response status code: {}", response.getStatus());

            if (response.getStatus() == 200) {
                String entity = response.readEntity(String.class);
                log.debug("User-Info response entity: {}", entity);
                final Jwt jwtUserInfo = Jwt.parse(entity);

                log.debug("User-Info response jwtUserInfo: {}", jwtUserInfo);

                UserInfoResponse userInfoResponse = new UserInfoResponse();
                userInfoResponse.setClaims(getClaims(jwtUserInfo));
                userInfoResponse.setJwtUserInfo(entity);

                log.debug("User-Info response userInfoResponse: {}", userInfoResponse);
                return userInfoResponse;
            }

        } catch (ApplicationException e) {
            log.error(ErrorResponse.GET_USER_INFO_ERROR.getDescription());
            throw e;
        } catch (Exception e) {
            log.error(ErrorResponse.GET_USER_INFO_ERROR.getDescription(), e);
            throw new ApplicationException(Response.Status.INTERNAL_SERVER_ERROR.getStatusCode(), ErrorResponse.GET_USER_INFO_ERROR.getDescription());
        }
        return null;
    }

    private static String scopeAsString(List<String> scopes) throws UnsupportedEncodingException {
        Set<String> scope = Sets.newHashSet();
        scope.addAll(scopes);
        return CommonUtils.joinAndUrlEncode(scope);
    }
}

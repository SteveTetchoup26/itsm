package fr.nordal.itsm.security;

import static org.assertj.core.api.Assertions.assertThat;

import com.nimbusds.jose.JOSEException;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jose.jwk.RSAKey;
import com.nimbusds.jose.jwk.gen.RSAKeyGenerator;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.function.UnaryOperator;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.assertj.MockMvcTester;

/**
 * The real security chain of the application (signature, issuer, audience, expiry), without
 * Keycloak: the test owns a key pair, publishes its public key on a local HTTP server in place of
 * Keycloak's JWKS endpoint, and signs its own tokens, valid or tampered with.
 */
@WebMvcTest(MeController.class)
@Import({SecurityConfiguration.class, JwtCurrentUserProvider.class})
class JwtAuthenticationTest {

    private static final String ISSUER = "http://keycloak.test/realms/nordal";
    private static final RSAKey KEYCLOAK_KEY = newKey("keycloak");
    private static final HttpServer JWKS_SERVER = startJwksServer();

    @DynamicPropertySource
    static void identityProvider(DynamicPropertyRegistry registry) {
        registry.add("ITSM_OIDC_ISSUER", () -> ISSUER);
        registry.add(
                "ITSM_OIDC_JWKS",
                () -> "http://127.0.0.1:" + JWKS_SERVER.getAddress().getPort() + "/certs");
    }

    @AfterAll
    static void stopJwksServer() {
        JWKS_SERVER.stop(0);
    }

    @Autowired
    MockMvcTester mvc;

    @Test
    void me_returns_the_user_described_by_a_valid_token() {
        String token = sign(KEYCLOAK_KEY, claims -> claims);

        assertThat(mvc.get().uri("/api/v1/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
                .hasStatusOk()
                .bodyJson()
                .isStrictlyEqualTo("""
                        {"id": "00000000-0000-4000-8000-000000000002", "username": "karim",
                         "name": "Karim Benali", "email": "karim.benali@nordal.example",
                         "roles": ["USER", "TECHNICIAN"]}
                        """);
    }

    @Test
    void a_request_with_a_bearer_token_needs_no_csrf_token() {
        String token = sign(KEYCLOAK_KEY, claims -> claims);

        // 405: the request went through the security chain and reached Spring MVC (403 would be CSRF).
        assertThat(mvc.post().uri("/api/v1/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
                .hasStatus(HttpStatus.METHOD_NOT_ALLOWED);
    }

    @Test
    void a_state_changing_request_without_bearer_token_still_needs_a_csrf_token() {
        assertThat(mvc.post().uri("/api/v1/me")).hasStatus(HttpStatus.FORBIDDEN);
    }

    @Test
    void no_token_is_refused() {
        assertThat(mvc.get().uri("/api/v1/me")).hasStatus(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void a_token_signed_by_another_key_is_refused() {
        assertRefused(sign(newKey("keycloak"), claims -> claims));
    }

    @Test
    void a_token_from_another_issuer_is_refused() {
        assertRefused(sign(KEYCLOAK_KEY, claims -> claims.issuer("http://keycloak.test/realms/other")));
    }

    @Test
    void a_token_issued_for_another_application_is_refused() {
        assertRefused(sign(KEYCLOAK_KEY, claims -> claims.audience("another-backend")));
    }

    @Test
    void an_expired_token_is_refused() {
        Instant tenMinutesAgo = Instant.now().minusSeconds(600);
        assertRefused(sign(
                KEYCLOAK_KEY,
                claims -> claims.issueTime(Date.from(tenMinutesAgo))
                        .expirationTime(Date.from(tenMinutesAgo.plusSeconds(300)))));
    }

    private void assertRefused(String token) {
        assertThat(mvc.get().uri("/api/v1/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
                .hasStatus(HttpStatus.UNAUTHORIZED);
    }

    /** A token shaped like Keycloak's for Karim; each test changes what it is about. */
    private static String sign(RSAKey key, UnaryOperator<JWTClaimsSet.Builder> change) {
        Instant now = Instant.now();
        var claims = new JWTClaimsSet.Builder()
                .issuer(ISSUER)
                .audience("itsm-backend")
                .subject("00000000-0000-4000-8000-000000000002")
                .issueTime(Date.from(now))
                .expirationTime(Date.from(now.plusSeconds(300)))
                .claim("preferred_username", "karim")
                .claim("name", "Karim Benali")
                .claim("email", "karim.benali@nordal.example")
                .claim("realm_access", Map.of("roles", List.of("TECHNICIAN", "USER", "offline_access")));
        var jwt = new SignedJWT(
                new JWSHeader.Builder(JWSAlgorithm.RS256).keyID(key.getKeyID()).build(),
                change.apply(claims).build());
        try {
            jwt.sign(new RSASSASigner(key));
        } catch (JOSEException e) {
            throw new IllegalStateException(e);
        }
        return jwt.serialize();
    }

    // Same key id for both keys: the forged token cannot be told apart by its header.
    private static RSAKey newKey(String keyId) {
        try {
            return new RSAKeyGenerator(2048).keyID(keyId).generate();
        } catch (JOSEException e) {
            throw new IllegalStateException(e);
        }
    }

    private static HttpServer startJwksServer() {
        try {
            var server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
            byte[] jwks = new JWKSet(KEYCLOAK_KEY.toPublicJWK()).toString().getBytes(StandardCharsets.UTF_8);
            server.createContext("/certs", exchange -> {
                exchange.getResponseHeaders().add("Content-Type", "application/json");
                exchange.sendResponseHeaders(200, jwks.length);
                exchange.getResponseBody().write(jwks);
                exchange.close();
            });
            server.start();
            return server;
        } catch (IOException e) {
            throw new IllegalStateException(e);
        }
    }
}

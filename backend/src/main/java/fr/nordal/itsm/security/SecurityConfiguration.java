package fr.nordal.itsm.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
class SecurityConfiguration {

    @Bean
    SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        return http.authorizeHttpRequests(requests -> requests
                        // Probes (Compose health checks) and smoke tests run without a user.
                        .requestMatchers("/actuator/health/**")
                        .permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/v1/system/info")
                        .permitAll()
                        // Closed by default: a new endpoint is protected unless listed above.
                        .anyRequest()
                        .authenticated())
                .oauth2ResourceServer(
                        server -> server.jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthenticationConverter())))
                // No HTTP session: each request is authenticated by its token alone.
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                // CSRF protects cookie-based sessions; a bearer token is never sent by the browser on its own.
                .csrf(AbstractHttpConfigurer::disable)
                .build();
    }

    // The authentication name stays the "sub" claim (stable identifier); authorities come from the realm roles.
    private static JwtAuthenticationConverter jwtAuthenticationConverter() {
        var converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(new KeycloakRealmRoleConverter());
        return converter;
    }
}

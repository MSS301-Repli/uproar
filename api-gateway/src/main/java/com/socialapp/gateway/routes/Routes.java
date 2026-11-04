package com.socialapp.gateway.routes;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.function.RequestPredicate;
import org.springframework.web.servlet.function.RouterFunction;
import org.springframework.web.servlet.function.ServerResponse;

import static com.socialapp.gateway.filter.UserHeaderFilter.forwardUserInfo;
import static org.springframework.cloud.gateway.server.mvc.filter.LoadBalancerFilterFunctions.lb;
import static org.springframework.cloud.gateway.server.mvc.handler.GatewayRouterFunctions.route;
import static org.springframework.cloud.gateway.server.mvc.handler.HandlerFunctions.http;
import static org.springframework.web.servlet.function.RequestPredicates.path;

/**
 * Path ownership: one prefix = one service. Service ids must equal each service's spring.application.name.
 * Routes to services that are not running yet return 503.
 */
@Configuration(proxyBeanMethods = false)
public class Routes {

    @Bean
    public RouterFunction<ServerResponse> identityRoute() {
        return to("identity-service", path("/api/auth/**").or(path("/api/admin/users/**")));
    }

    @Bean
    public RouterFunction<ServerResponse> profileRoute() {
        return to("profile-service", path("/api/profiles/**"));
    }

    @Bean
    public RouterFunction<ServerResponse> postRoute() {
        return to("post-service", path("/api/posts/**").or(path("/api/admin/posts/**")));
    }

    @Bean
    public RouterFunction<ServerResponse> notificationRoute() {
        return to("notification-service", path("/api/notifications/**"));
    }

    @Bean
    public RouterFunction<ServerResponse> chatRoute() {
        return to("chat-service", path("/api/conversations/**"));
    }

    private static RouterFunction<ServerResponse> to(String serviceId, RequestPredicate predicate) {
        return route(serviceId)
                .route(predicate, http())
                .before(forwardUserInfo())
                .filter(lb(serviceId))
                .build();
    }
}

package com.socialapp.gateway.config;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.servlet.HandlerExceptionResolver;
import org.springframework.web.servlet.ModelAndView;

import java.io.IOException;

/**
 * When a service is down, the load balancer throws "503 Unable to find instance for X".
 * Without this the client gets a misleading 500; here we keep the original status (503).
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class UpstreamErrorResolver implements HandlerExceptionResolver {

    @Override
    public ModelAndView resolveException(HttpServletRequest request, HttpServletResponse response,
                                         Object handler, Exception ex) {
        if (!(ex instanceof HttpStatusCodeException upstream)) {
            return null; // let the default resolvers handle it
        }
        try {
            response.sendError(upstream.getStatusCode().value(), upstream.getStatusText());
        } catch (IOException ignored) {
            // response already committed: nothing more we can do
        }
        return new ModelAndView();
    }
}

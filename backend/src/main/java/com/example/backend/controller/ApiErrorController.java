package com.example.backend.controller;

import jakarta.servlet.RequestDispatcher;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.boot.webmvc.error.ErrorController;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

@RestController
public class ApiErrorController implements ErrorController {

    @RequestMapping("/error")
    public ResponseEntity<Map<String, Object>> handleError(HttpServletRequest request) {
        Object statusCode = request.getAttribute(RequestDispatcher.ERROR_STATUS_CODE);
        HttpStatus status = statusCode != null
                ? HttpStatus.valueOf(Integer.parseInt(statusCode.toString()))
                : HttpStatus.INTERNAL_SERVER_ERROR;

        Object upstreamMessage = request.getAttribute(RequestDispatcher.ERROR_MESSAGE);
        Object requestUri = request.getAttribute(RequestDispatcher.ERROR_REQUEST_URI);
        String message = shouldUseFriendlyMessage(status, upstreamMessage, requestUri)
                ? messageFor(status)
                : upstreamMessage.toString();

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("timestamp", Instant.now().toString());
        body.put("status", status.value());
        body.put("error", status.getReasonPhrase());
        body.put("path", request.getAttribute(RequestDispatcher.ERROR_REQUEST_URI));
        body.put("message", message);

        return ResponseEntity.status(status).body(body);
    }

    private boolean shouldUseFriendlyMessage(HttpStatus status, Object upstreamMessage, Object requestUri) {
        if (upstreamMessage == null || upstreamMessage.toString().isBlank()) {
            return true;
        }
        if (status.is5xxServerError()) {
            // Never leak the raw exception message (may contain internal/DB details).
            return true;
        }
        if (status == HttpStatus.NOT_FOUND) {
            // A 404 inside our own API surface is a deliberate "resource not found" from our
            // own code (e.g. "Product 999 not found") - that message is worth keeping. Anything
            // outside /api/products is a genuinely unmapped route, so point people at the real API.
            String path = requestUri == null ? "" : requestUri.toString();
            return !path.startsWith("/api/products");
        }
        return false;
    }

    private String messageFor(HttpStatus status) {
        if (status == HttpStatus.NOT_FOUND) {
            return "No endpoint here. The API lives under /api/products.";
        }
        if (status == HttpStatus.BAD_REQUEST) {
            return "The server couldn't process that request. Check that all product fields are valid.";
        }
        return "Something went wrong handling that request.";
    }

}

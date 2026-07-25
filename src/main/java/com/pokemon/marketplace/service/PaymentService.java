package com.pokemon.marketplace.service;

import com.pokemon.marketplace.config.VNPayConfig;
import com.pokemon.marketplace.entity.Order;
import com.pokemon.marketplace.entity.TopUpTransaction;
import com.pokemon.marketplace.entity.enums.OrderStatus;
import com.pokemon.marketplace.exception.ResourceNotFoundException;
import com.pokemon.marketplace.repository.OrderRepository;
import com.pokemon.marketplace.repository.TopUpTransactionRepository;
import com.pokemon.marketplace.repository.UserRepository;
import com.pokemon.marketplace.entity.User;
import java.time.LocalDateTime;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.io.UnsupportedEncodingException;
import java.math.BigDecimal;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class PaymentService {

    private final VNPayConfig vnpConfig;
    private final OrderRepository orderRepository;
    private final OrderService orderService;
    private final TopUpTransactionRepository topUpTransactionRepository;
    private final UserRepository userRepository;

    private static final BigDecimal EXCHANGE_RATE_USD_VND = new BigDecimal("25000");

    @Transactional(readOnly = true)
    public String createPaymentUrl(Long orderId, HttpServletRequest request) {
        return createPaymentUrl(orderId, request, "web");
    }

    @Transactional(readOnly = true)
    public String createPaymentUrl(Long orderId, HttpServletRequest request, String platform) {
        log.info("Generating VNPay payment URL for Order ID: {}, platform: {}", orderId, platform);
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new ResourceNotFoundException("Order not found with ID: " + orderId));

        
        BigDecimal amountVnd = order.getTotalAmount().multiply(EXCHANGE_RATE_USD_VND);
        long amountVndCents = amountVnd.multiply(BigDecimal.valueOf(100)).longValue();

        String ipAddress = VNPayConfig.getIpAddress(request);

        Map<String, String> vnp_Params = new HashMap<>();
        vnp_Params.put("vnp_Version", "2.1.0");
        vnp_Params.put("vnp_Command", "pay");
        vnp_Params.put("vnp_TmnCode", vnpConfig.getTmnCode());
        vnp_Params.put("vnp_Amount", String.valueOf(amountVndCents));
        vnp_Params.put("vnp_CurrCode", "VND");
        vnp_Params.put("vnp_TxnRef", String.valueOf(orderId));
        vnp_Params.put("vnp_OrderInfo", "ThanhToanDonHangPokemon" + orderId);
        vnp_Params.put("vnp_OrderType", "other");
        vnp_Params.put("vnp_Locale", "vn");
        vnp_Params.put("vnp_ReturnUrl", getDynamicReturnUrl(request, platform));
        vnp_Params.put("vnp_IpAddr", ipAddress);

        Calendar cld = Calendar.getInstance(TimeZone.getTimeZone("Asia/Ho_Chi_Minh"));
        SimpleDateFormat formatter = new SimpleDateFormat("yyyyMMddHHmmss");
        formatter.setTimeZone(TimeZone.getTimeZone("Asia/Ho_Chi_Minh"));
        String vnp_CreateDate = formatter.format(cld.getTime());
        vnp_Params.put("vnp_CreateDate", vnp_CreateDate);

        cld.add(Calendar.MINUTE, 15);
        String vnp_ExpireDate = formatter.format(cld.getTime());
        vnp_Params.put("vnp_ExpireDate", vnp_ExpireDate);

        List<String> fieldNames = new ArrayList<>(vnp_Params.keySet());
        Collections.sort(fieldNames);
        StringBuilder hashData = new StringBuilder();
        StringBuilder query = new StringBuilder();

        try {
            boolean first = true;
            for (String fieldName : fieldNames) {
                String fieldValue = vnp_Params.get(fieldName);
                if (fieldValue != null && !fieldValue.isEmpty()) {
                    String encodedValue = URLEncoder.encode(fieldValue, StandardCharsets.UTF_8.toString()).replace("+", "%20");
                    String encodedName = URLEncoder.encode(fieldName, StandardCharsets.UTF_8.toString()).replace("+", "%20");
                    
                    if (!first) {
                        hashData.append('&');
                        query.append('&');
                    }
                    first = false;
                    
                    hashData.append(fieldName).append('=').append(encodedValue);
                    query.append(encodedName).append('=').append(encodedValue);
                }
            }
        } catch (UnsupportedEncodingException e) {
            log.error("Encoding error while generating VNPay query string", e);
            throw new RuntimeException("Payment query generation failed", e);
        }

        String queryUrl = query.toString();
        log.info("VNPay HashSecret length: {}, TmnCode length: {}", vnpConfig.getHashSecret().length(), vnpConfig.getTmnCode().length());
        log.info("VNPay hashData string: {}", hashData.toString());
        String vnp_SecureHash = VNPayConfig.hmacSHA512(vnpConfig.getHashSecret(), hashData.toString());
        queryUrl += "&vnp_SecureHash=" + vnp_SecureHash;
        String finalUrl = vnpConfig.getPayUrl() + "?" + queryUrl;
        log.info("Generated VNPay payment URL for Order ID {}: {}", orderId, finalUrl);
        return finalUrl;
    }

    @Transactional
    public String createTopUpPaymentUrl(BigDecimal amount, Long userId, HttpServletRequest request) {
        return createTopUpPaymentUrl(amount, userId, request, "web");
    }

    @Transactional
    public String createTopUpPaymentUrl(BigDecimal amount, Long userId, HttpServletRequest request, String platform) {
        log.info("Generating VNPay top-up payment URL for User ID: {}, Amount: {}, platform: {}", userId, amount, platform);

        
        String txnRef = "TOPUP_" + UUID.randomUUID().toString().replaceAll("-", "").substring(0, 16);

        
        TopUpTransaction transaction = TopUpTransaction.builder()
                .id(txnRef)
                .userId(userId)
                .amount(amount)
                .status("PENDING")
                .createdAt(LocalDateTime.now())
                .build();
        topUpTransactionRepository.save(transaction);

        
        BigDecimal amountVnd = amount.multiply(EXCHANGE_RATE_USD_VND);
        long amountVndCents = amountVnd.multiply(BigDecimal.valueOf(100)).longValue();

        String ipAddress = VNPayConfig.getIpAddress(request);

        Map<String, String> vnp_Params = new HashMap<>();
        vnp_Params.put("vnp_Version", "2.1.0");
        vnp_Params.put("vnp_Command", "pay");
        vnp_Params.put("vnp_TmnCode", vnpConfig.getTmnCode());
        vnp_Params.put("vnp_Amount", String.valueOf(amountVndCents));
        vnp_Params.put("vnp_CurrCode", "VND");
        vnp_Params.put("vnp_TxnRef", txnRef);
        vnp_Params.put("vnp_OrderInfo", "NapTienTaiKhoanPokemon" + txnRef);
        vnp_Params.put("vnp_OrderType", "other");
        vnp_Params.put("vnp_Locale", "vn");
        vnp_Params.put("vnp_ReturnUrl", getDynamicReturnUrl(request, platform));
        vnp_Params.put("vnp_IpAddr", ipAddress);

        Calendar cld = Calendar.getInstance(TimeZone.getTimeZone("Asia/Ho_Chi_Minh"));
        SimpleDateFormat formatter = new SimpleDateFormat("yyyyMMddHHmmss");
        formatter.setTimeZone(TimeZone.getTimeZone("Asia/Ho_Chi_Minh"));
        String vnp_CreateDate = formatter.format(cld.getTime());
        vnp_Params.put("vnp_CreateDate", vnp_CreateDate);

        cld.add(Calendar.MINUTE, 15);
        String vnp_ExpireDate = formatter.format(cld.getTime());
        vnp_Params.put("vnp_ExpireDate", vnp_ExpireDate);

        List<String> fieldNames = new ArrayList<>(vnp_Params.keySet());
        Collections.sort(fieldNames);
        StringBuilder hashData = new StringBuilder();
        StringBuilder query = new StringBuilder();

        try {
            boolean first = true;
            for (String fieldName : fieldNames) {
                String fieldValue = vnp_Params.get(fieldName);
                if (fieldValue != null && !fieldValue.isEmpty()) {
                    String encodedValue = URLEncoder.encode(fieldValue, StandardCharsets.UTF_8.toString()).replace("+", "%20");
                    String encodedName = URLEncoder.encode(fieldName, StandardCharsets.UTF_8.toString()).replace("+", "%20");
                    
                    if (!first) {
                        hashData.append('&');
                        query.append('&');
                    }
                    first = false;
                    
                    hashData.append(fieldName).append('=').append(encodedValue);
                    query.append(encodedName).append('=').append(encodedValue);
                }
            }
        } catch (UnsupportedEncodingException e) {
            log.error("Encoding error while generating VNPay query string for top-up", e);
            throw new RuntimeException("Top-up payment query generation failed", e);
        }

        String queryUrl = query.toString();
        String vnp_SecureHash = VNPayConfig.hmacSHA512(vnpConfig.getHashSecret(), hashData.toString());
        queryUrl += "&vnp_SecureHash=" + vnp_SecureHash;
        String finalUrl = vnpConfig.getPayUrl() + "?" + queryUrl;
        log.info("Generated VNPay top-up payment URL for User ID {}: {}", userId, finalUrl);
        return finalUrl;
    }

    @Transactional
    public boolean processCallback(Map<String, String> params) {
        log.info("Processing VNPay payment callback parameters");
        String vnp_SecureHash = params.get("vnp_SecureHash");
        if (vnp_SecureHash == null) {
            log.warn("VNPay secure hash signature missing in query parameters");
            return false;
        }

        
        Map<String, String> checkParams = new HashMap<>(params);
        checkParams.remove("vnp_SecureHash");
        checkParams.remove("vnp_SecureHashType");

        List<String> fieldNames = new ArrayList<>(checkParams.keySet());
        Collections.sort(fieldNames);
        StringBuilder hashData = new StringBuilder();

        try {
            boolean first = true;
            for (String fieldName : fieldNames) {
                String fieldValue = checkParams.get(fieldName);
                if (fieldValue != null && !fieldValue.isEmpty()) {
                    String encodedValue = URLEncoder.encode(fieldValue, StandardCharsets.UTF_8.toString()).replace("+", "%20");
                    
                    if (!first) {
                        hashData.append('&');
                    }
                    first = false;
                    
                    hashData.append(fieldName).append('=').append(encodedValue);
                }
            }
        } catch (UnsupportedEncodingException e) {
            log.error("Encoding error during signature verification", e);
            return false;
        }

        String calculatedHash = VNPayConfig.hmacSHA512(vnpConfig.getHashSecret(), hashData.toString());
        if (!calculatedHash.equalsIgnoreCase(vnp_SecureHash)) {
            log.error("Signature mismatch! Calculated: {}, Received: {}", calculatedHash, vnp_SecureHash);
            return false;
        }

        String responseCode = params.get("vnp_ResponseCode");
        String txnRef = params.get("vnp_TxnRef");
        if (txnRef == null) {
            log.error("VNPay transaction reference (vnp_TxnRef) is missing");
            return false;
        }

        
        if (txnRef.startsWith("TOPUP_")) {
            Optional<TopUpTransaction> transactionOpt = topUpTransactionRepository.findById(txnRef);
            if (transactionOpt.isEmpty()) {
                log.error("Top-up transaction not found with ID: {}", txnRef);
                return false;
            }
            TopUpTransaction transaction = transactionOpt.get();
            if ("SUCCESS".equals(transaction.getStatus())) {
                log.info("Top-up transaction {} was already processed successfully", txnRef);
                return true;
            }
            if ("00".equals(responseCode)) {
                log.info("VNPay Payment SUCCESS for Top-Up ID: {}", txnRef);
                transaction.setStatus("SUCCESS");
                topUpTransactionRepository.save(transaction);
                
                // Credit the user's balance
                Optional<User> userOpt = userRepository.findById(transaction.getUserId());
                if (userOpt.isPresent()) {
                    User user = userOpt.get();
                    user.setBalance((user.getBalance() != null ? user.getBalance() : 0.0) + transaction.getAmount().doubleValue());
                    userRepository.save(user);
                    log.info("Credited User ID {} with amount {} USD via VNPay. New balance: {}", user.getId(), transaction.getAmount(), user.getBalance());
                } else {
                    log.error("User ID {} not found for top-up transaction {}", transaction.getUserId(), txnRef);
                }
                
                return true;
            } else {
                log.warn("VNPay Payment FAILED/CANCELLED for Top-Up ID: {} with response code: {}", txnRef, responseCode);
                transaction.setStatus("FAILED");
                topUpTransactionRepository.save(transaction);
                return false;
            }
        }

        
        Long orderId = Long.parseLong(txnRef);

        if ("00".equals(responseCode)) {
            log.info("VNPay Payment SUCCESS for Order ID: {}", orderId);
            orderService.updateOrderStatus(orderId, OrderStatus.PROCESSING);
            return true;
        } else {
            log.warn("VNPay Payment FAILED/CANCELLED for Order ID: {} with response code: {}", orderId, responseCode);
            orderService.updateOrderStatus(orderId, OrderStatus.CANCELLED);
            return false;
        }
    }

    private String getDynamicReturnUrl(HttpServletRequest request, String platform) {
        String returnUrl = vnpConfig.getReturnUrl();
        if (request != null) {
            String serverName = request.getServerName();
            if (serverName != null && !serverName.equals("localhost") && !serverName.equals("127.0.0.1")) {
                returnUrl = returnUrl.replace("localhost", serverName);
            }
        }
        if ("mobile".equals(platform)) {
            if (request != null) {
                String serverName = request.getServerName();
                if (serverName != null && !serverName.equals("localhost") && !serverName.equals("127.0.0.1")) {
                    returnUrl = "http://" + serverName + "/api/payment/mobile-return";
                } else {
                    returnUrl = "http://localhost:8080/api/payment/mobile-return";
                }
            } else {
                returnUrl = "http://localhost:8080/api/payment/mobile-return";
            }
        }
        return returnUrl;
    }
}

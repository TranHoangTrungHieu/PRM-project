package com.pokemon.marketplace.dto;

import com.pokemon.marketplace.entity.enums.OrderStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrderDTO {
    private Long id;
    private Long userId;
    private String recipientName;
    private String phone;
    private String shippingAddress;
    private String note;
    private String paymentMethod;
    private String deliveryType;
    private BigDecimal totalAmount;
    private OrderStatus status;
    private LocalDateTime createdAt;
    private String bankTranDateTime;
    private Long auctionId;
    private String cancelReason;
    private String cancelledBy;
    private List<OrderItemDTO> items;
}

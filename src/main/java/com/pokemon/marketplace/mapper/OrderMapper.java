package com.pokemon.marketplace.mapper;

import com.pokemon.marketplace.dto.OrderDTO;
import com.pokemon.marketplace.dto.OrderItemDTO;
import com.pokemon.marketplace.entity.Order;
import com.pokemon.marketplace.entity.OrderItem;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import java.util.stream.Collectors;

@Component
@RequiredArgsConstructor
public class OrderMapper {

    private final ProductMapper productMapper;

    public OrderDTO toDTO(Order order) {
        if (order == null) return null;
        return OrderDTO.builder()
                .id(order.getId())
                .userId(order.getUser().getId())
                .recipientName(order.getRecipientName())
                .phone(order.getPhone())
                .shippingAddress(order.getShippingAddress())
                .note(order.getNote())
                .paymentMethod(order.getPaymentMethod())
                .deliveryType(order.getDeliveryType())
                .totalAmount(order.getTotalAmount())
                .status(order.getStatus())
                .createdAt(order.getCreatedAt())
                .bankTranDateTime(order.getBankTranDateTime())
                .auctionId(order.getAuctionId())
                .cancelReason(order.getCancelReason())
                .cancelledBy(order.getCancelledBy())
                .items(order.getItems().stream().map(this::toItemDTO).collect(Collectors.toList()))
                .build();
    }

    private OrderItemDTO toItemDTO(OrderItem item) {
        if (item == null) return null;
        return OrderItemDTO.builder()
                .id(item.getId())
                .product(productMapper.toDTO(item.getProduct()))
                .price(item.getPrice())
                .quantity(item.getQuantity())
                .build();
    }
}

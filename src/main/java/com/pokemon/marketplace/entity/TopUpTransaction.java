package com.pokemon.marketplace.entity;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;
import org.springframework.data.mongodb.core.mapping.Field;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Document(collection = "topup_transactions")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TopUpTransaction {

    @Id
    private String id; 

    @Field("user_id")
    private Long userId;

    private BigDecimal amount; 

    private String status; 

    @Field("created_at")
    private LocalDateTime createdAt;

    @Field("bank_tran_date_time")
    private String bankTranDateTime; // vnp_PayDate from VNPay callback (yyyyMMddHHmmss)
}

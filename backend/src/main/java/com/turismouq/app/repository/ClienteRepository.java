package com.turismouq.app.repository;

import com.turismouq.app.entity.Cliente;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ClienteRepository extends JpaRepository<Cliente, Long> {
    List<Cliente> findTop50ByOrderByApellidosAscNombresAsc();
}
